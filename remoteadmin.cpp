#include "remoteadmin.h"
#include "controller.h"

#include <QtCore/QJsonDocument>
#include <QtCore/QSysInfo>
#include <QtCore/QUrl>
#include <QtCore/qloggingcategory.h>
#include <QtNetwork/QAbstractSocket>
#include <QtNetwork/QHostAddress>
#include <QtNetwork/QNetworkInterface>
#include <QtNetwork/QTcpSocket>

#include <memory>

Q_LOGGING_CATEGORY(remoteAdmin, "qthass.remoteadmin")

RemoteAdmin::RemoteAdmin(Controler *controler, QObject *parent)
    : QObject(parent), controler_(controler) {
  commands_["deviceInfo"] = [this](const QUrlQuery &q) { return cmdDeviceInfo(q); };
  commands_["startScreensaver"] = [this](const QUrlQuery &q) { return cmdStartScreensaver(q); };
  commands_["stopScreensaver"] = [this](const QUrlQuery &q) { return cmdStopScreensaver(q); };
  commands_["getStringSetting"] = [this](const QUrlQuery &q) { return cmdGetStringSetting(q); };
  commands_["setStringSetting"] = [this](const QUrlQuery &q) { return cmdSetStringSetting(q); };
  commands_["listSettings"] = [this](const QUrlQuery &q) { return cmdListSettings(q); };

  connect(&server_, &QTcpServer::newConnection, this, &RemoteAdmin::handleNewConnection);
}

void RemoteAdmin::start() {
  if (controler_->remoteAdminPassword().isEmpty()) {
    qCWarning(remoteAdmin) << "REMOTE_ADMIN_PASSWORD not set in config -- "
                              "remote admin server disabled";
    return;
  }

  if (!server_.listen(QHostAddress::Any, controler_->remoteAdminPort())) {
    qCWarning(remoteAdmin) << "Could not start remote admin server on port"
                            << controler_->remoteAdminPort() << ":"
                            << server_.errorString();
    return;
  }

  qCInfo(remoteAdmin) << "Remote admin server listening on port"
                       << controler_->remoteAdminPort();
}

void RemoteAdmin::handleNewConnection() {
  while (server_.hasPendingConnections()) {
    QTcpSocket *socket = server_.nextPendingConnection();

    // GET-only, no body -- the request line is all we need. Buffer per
    // connection until it's complete; a std::shared_ptr keeps this lambda's
    // own copy alive across however many readyRead deliveries it takes.
    auto buffer = std::make_shared<QByteArray>();
    connect(socket, &QTcpSocket::readyRead, this, [this, socket, buffer]() {
      buffer->append(socket->readAll());
      const auto end = buffer->indexOf("\r\n");
      if (end < 0)
        return; // wait for the rest of the request line
      handleRequest(socket, buffer->left(end));
    });
    connect(socket, &QTcpSocket::disconnected, socket, &QObject::deleteLater);
  }
}

void RemoteAdmin::handleRequest(QTcpSocket *socket, const QByteArray &requestLine) {
  const QList<QByteArray> parts = requestLine.split(' ');
  if (parts.size() < 2 || parts.at(0) != "GET") {
    writeResponse(socket, 400,
                  {{"status", "Error"}, {"statustext", "Only GET is supported"}});
    return;
  }

  const QUrl url{QString::fromUtf8(parts.at(1))};
  const QUrlQuery query{url};

  if (controler_->remoteAdminPassword().isEmpty() ||
      query.queryItemValue("password") != controler_->remoteAdminPassword()) {
    writeResponse(socket, 401,
                  {{"status", "Error"}, {"statustext", "Wrong password"}});
    return;
  }

  const QString cmd = query.queryItemValue("cmd");
  if (!commands_.contains(cmd)) {
    writeResponse(socket, 400,
                  {{"status", "Error"}, {"statustext", "Unknown command"}});
    return;
  }

  writeResponse(socket, 200, commands_.value(cmd)(query));
}

void RemoteAdmin::writeResponse(QTcpSocket *socket, int statusCode,
                                const QJsonObject &body) {
  const QByteArray json = QJsonDocument{body}.toJson(QJsonDocument::Compact);
  const QByteArray statusText = statusCode == 200   ? "OK"
                                 : statusCode == 401 ? "Unauthorized"
                                                      : "Bad Request";
  const QByteArray response = "HTTP/1.1 " + QByteArray::number(statusCode) + " " +
                              statusText + "\r\n" +
                              "Content-Type: application/json\r\n" +
                              "Content-Length: " +
                              QByteArray::number(json.size()) + "\r\n" +
                              "Connection: close\r\n\r\n" + json;
  socket->write(response);
  socket->disconnectFromHost();
}

// Home Assistant's own "Fully Kiosk Browser" integration (as opposed to the
// generic rest/rest_command/switch platforms CLAUDE.md recommends pointing
// at this server) reads several of these fields straight out of this
// response with no .get()/default:
//   - config_flow.py's _create_entry: deviceID, deviceName,
//     format_mac(Mac) -- required for "Add device" to succeed at all.
//   - entity.py's FullyKioskEntity.__init__ -- the base class practically
//     every entity platform (switch, camera, media_player, notify, image,
//     button) constructs -- additionally requires ip4, deviceManufacturer,
//     deviceModel, appVersionName; missing any of these throws a bare
//     KeyError there and that whole platform creates zero entities
//     (confirmed via HA's own logs, one field short at a time).
// sensor.py/binary_sensor.py are better-behaved (coordinator.data.get(...)
// plus an `if description.key in coordinator.data` existence check), but
// this app has no equivalent for what they actually want (battery, RAM,
// storage, foreground app, screen orientation, etc), so those stay absent
// rather than faked -- this is still not a full drop-in.
QJsonObject RemoteAdmin::cmdDeviceInfo(const QUrlQuery &) const {
  const QString mac = controler_->deviceId();
  QString name = QSysInfo::machineHostName();
  if (name.isEmpty())
    name = QStringLiteral("qthomeassistant");

  return {
      {"status", "OK"},
      {"deviceID", mac},
      {"deviceName", name},
      {"deviceManufacturer", QStringLiteral("qthomeassistant")},
      {"deviceModel", QSysInfo::prettyProductName()},
      {"appVersionName", QStringLiteral(APP_VERSION)},
      {"Mac", mac},
      {"ip4", deviceIp()},
      {"screensaverActive", controler_->screensaverActive()},
      // switch.py's "screensaver" entity reads its on/off state from this
      // exact key (is_on_fn=lambda data: data.get("isInScreensaver")) --
      // without it the switch always reads back "off" no matter what
      // startScreensaver/stopScreensaver actually did, since screensaverActive
      // above is this app's own name for the same thing, not Fully Kiosk's.
      {"isInScreensaver", controler_->screensaverActive()},
      {"idleTimeoutSeconds", controler_->idleTimeoutSeconds()},
      {"hassConnected", controler_->hassConnected()},
  };
}

QString RemoteAdmin::deviceIp() const {
  for (const QHostAddress &address : QNetworkInterface::allAddresses()) {
    if (address.protocol() == QAbstractSocket::IPv4Protocol && !address.isLoopback())
      return address.toString();
  }
  return QStringLiteral("127.0.0.1");
}

QJsonObject RemoteAdmin::cmdStartScreensaver(const QUrlQuery &) {
  controler_->setScreensaverActive(true);
  return {{"status", "OK"}};
}

QJsonObject RemoteAdmin::cmdStopScreensaver(const QUrlQuery &) {
  controler_->setScreensaverActive(false);
  return {{"status", "OK"}};
}

// idleTimeoutSeconds is our own setting key, not a verified real Fully Kiosk
// one -- see CLAUDE.md's remote admin section.
QJsonObject RemoteAdmin::cmdGetStringSetting(const QUrlQuery &query) const {
  const QString key = query.queryItemValue("key");
  if (key == "idleTimeoutSeconds")
    return {{"status", "OK"},
            {"value", QString::number(controler_->idleTimeoutSeconds())}};
  return {{"status", "Error"}, {"statustext", "Unknown setting key"}};
}

// python-fullykiosk's getSettings() -- called by HA's fully_kiosk
// coordinator on every refresh, separately from the per-key
// getStringSetting/setStringSetting above -- maps to cmd=listSettings, not
// "getSettings". Real Fully Kiosk returns its entire settings dump here;
// this app only has idleTimeoutSeconds, plus mqttEnabled/mqttEventTopic --
// entity.py's mqtt_subscribe() (called from switch.py's
// async_added_to_hass() for the screensaver/screen switches) does
// data["settings"]["mqttEnabled"] unconditionally once HA's own MQTT
// integration is configured, and a bare KeyError there breaks the entity
// (observed as it going permanently "unavailable" -- the exception happens
// after the entity's already added, so it never gets a first
// _handle_coordinator_update). mqttEnabled mirrors whether MqttPublisher is
// configured (MQTT_BROKER_HOST set, see Controler) -- when it is,
// mqttEventTopic is the same $appId/$event/$deviceId template
// (kMqttEventTopicTemplate, controller.h) MqttPublisher resolves before
// publishing, so mqtt_subscribe()'s topic construction lands on exactly what
// gets published; see mqttpublisher.cpp for the onScreensaverStart/Stop
// events this exists for. No "status" wrapper: the coordinator merges this
// object as-is under deviceInfo's "settings" key.
QJsonObject RemoteAdmin::cmdListSettings(const QUrlQuery &) const {
  const bool mqttEnabled = !controler_->mqttBrokerHost().isEmpty();
  QJsonObject result{{"idleTimeoutSeconds", controler_->idleTimeoutSeconds()},
                      {"mqttEnabled", mqttEnabled}};
  if (mqttEnabled)
    result["mqttEventTopic"] = kMqttEventTopicTemplate;
  return result;
}

QJsonObject RemoteAdmin::cmdSetStringSetting(const QUrlQuery &query) {
  const QString key = query.queryItemValue("key");
  if (key != "idleTimeoutSeconds")
    return {{"status", "Error"}, {"statustext", "Unknown setting key"}};

  bool ok = false;
  const int seconds = query.queryItemValue("value").toInt(&ok);
  if (!ok || seconds <= 0)
    return {{"status", "Error"},
            {"statustext", "value must be a positive integer"}};

  controler_->setIdleTimeoutSeconds(seconds);
  return {{"status", "OK"}};
}
