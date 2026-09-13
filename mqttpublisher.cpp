#include "mqttpublisher.h"
#include "controller.h"

#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <QtCore/qloggingcategory.h>

#include <chrono>

Q_LOGGING_CATEGORY(mqttPublisher, "qthass.mqtt")

namespace {
// How long to wait before retrying a dropped/failed connection. No backoff --
// the simplest thing that works for a LAN broker that's expected to be up.
constexpr auto kReconnectInterval = std::chrono::seconds(5);
} // namespace

MqttPublisher::MqttPublisher(Controler *controler, QObject *parent)
    : QObject(parent), controler_(controler) {
  reconnect_timer_.setSingleShot(true);
  reconnect_timer_.setInterval(
      std::chrono::duration_cast<std::chrono::milliseconds>(kReconnectInterval)
          .count());
  connect(&reconnect_timer_, &QTimer::timeout, &client_,
          [this]() { client_.connectToHost(); });

  connect(&client_, &QMqttClient::connected, this,
          [this]() { qCInfo(mqttPublisher) << "Connected to" << client_.hostname(); });
  connect(&client_, &QMqttClient::disconnected, this, [this]() {
    qCWarning(mqttPublisher) << "Disconnected from broker, retrying in"
                              << kReconnectInterval.count() << "s";
    reconnect_timer_.start();
  });

  connect(controler_, &Controler::screensaverActiveChanged, this, [this]() {
    publishScreensaverState(controler_->screensaverActive());
  });
}

void MqttPublisher::start() {
  if (controler_->mqttBrokerHost().isEmpty()) {
    qCInfo(mqttPublisher) << "MQTT_BROKER_HOST not set in config -- "
                             "screensaver state won't be published over MQTT";
    return;
  }

  client_.setHostname(controler_->mqttBrokerHost());
  client_.setPort(controler_->mqttBrokerPort());
  if (!controler_->mqttUsername().isEmpty())
    client_.setUsername(controler_->mqttUsername());
  if (!controler_->mqttPassword().isEmpty())
    client_.setPassword(controler_->mqttPassword());
  client_.setClientId(QStringLiteral("qthomeassistant-") + controler_->deviceId());

  qCInfo(mqttPublisher) << "Connecting to" << controler_->mqttBrokerHost() << ":"
                        << controler_->mqttBrokerPort();
  client_.connectToHost();
}

void MqttPublisher::publishScreensaverState(bool active) {
  if (client_.state() != QMqttClient::Connected) {
    qCWarning(mqttPublisher) << "Not connected -- dropping screensaver state publish";
    return;
  }

  const QString eventName =
      active ? QStringLiteral("onScreensaverStart") : QStringLiteral("onScreensaverStop");
  const QString topic = QString{kMqttEventTopicTemplate}
                            .replace("$appId", "fully")
                            .replace("$event", eventName)
                            .replace("$deviceId", controler_->deviceId());
  const QByteArray payload =
      QJsonDocument{QJsonObject{{"event", eventName}}}.toJson(QJsonDocument::Compact);

  qCDebug(mqttPublisher) << "Publishing" << payload << "to" << topic;
  client_.publish(QMqttTopicName{topic}, payload, /*qos=*/1);
}
