#ifndef CONTROLLER
#define CONTROLLER

#include <QtCore/QHash>
#include <QtCore/QObject>
#include <QtCore/QStringList>
#include <QtCore/QTimer>
#include <QtCore/QVariant>
#include <QtQml/qqmlregistration.h>

class QQmlEngine;
class QJSEngine;

// The template HA's fully_kiosk integration expects in listSettings'
// mqttEventTopic (entity.py's mqtt_subscribe replaces $appId with "fully",
// $event with the event name, and $deviceId with deviceInfo's deviceID) --
// shared between RemoteAdmin::cmdListSettings() (which advertises it) and
// MqttPublisher (which resolves it the same way to publish to it).
inline constexpr auto kMqttEventTopicTemplate = "$appId/event/$event/$deviceId";

class Controler : public QObject {
  Q_OBJECT
  QML_ELEMENT
  QML_SINGLETON
  Q_PROPERTY(QString hassUrl READ hassUrl WRITE setHassUrl NOTIFY
                 hassUrlChanged)
  Q_PROPERTY(QString hassToken READ hassToken WRITE setHassToken NOTIFY
                 hassTokenChanged)
  Q_PROPERTY(bool screensaverActive READ screensaverActive WRITE
                 setScreensaverActive NOTIFY screensaverActiveChanged);
  // Seconds without user input before the screensaver starts.
  Q_PROPERTY(int idleTimeoutSeconds READ idleTimeoutSeconds WRITE
                 setIdleTimeoutSeconds NOTIFY idleTimeoutSecondsChanged);
  Q_PROPERTY(bool hassConnected READ hassConnected WRITE setHassConnected
                 NOTIFY hassConnectedChanged);
  Q_PROPERTY(QString mqttBrokerHost READ mqttBrokerHost NOTIFY mqttConfigChanged)
  Q_PROPERTY(int mqttBrokerPort READ mqttBrokerPort NOTIFY mqttConfigChanged)
  Q_PROPERTY(QString mqttUsername READ mqttUsername NOTIFY mqttConfigChanged)
  Q_PROPERTY(QString mqttPassword READ mqttPassword NOTIFY mqttConfigChanged)
  // Whether this build has Qt MQTT at all (MqttPublisher compiled in).
  Q_PROPERTY(bool mqttSupported READ mqttSupported CONSTANT)
  // Set by MqttPublisher; always false without mqttSupported.
  Q_PROPERTY(bool mqttConnected READ mqttConnected NOTIFY mqttConnectedChanged)

public:
  static Controler *create(QQmlEngine *, QJSEngine *) {
    if (!s_instance)
      s_instance = new Controler();
    return s_instance;
  }
  static Controler *instance() { return s_instance; }

  Controler(QObject *parent = nullptr);

  // HASS_URL/HASS_TOKEN, resolved in increasing priority from the bundled
  // :/qt-hass/config resource (generated at configure time), the process
  // environment, and values saved from the settings page. Setting them saves
  // them; HassAPI::reconnect() picks them up.
  QString hassUrl() const noexcept { return hass_url_; }
  QString hassToken() const noexcept { return hass_token_; }
  void setHassUrl(const QString &url);
  void setHassToken(const QString &token);
  // Forgets URL/token saved from the settings page, falling back to the
  // environment and bundled config again.
  Q_INVOKABLE void clearSavedConnection();

  bool screensaverActive() const noexcept { return screensaver_active_; }
  void setScreensaverActive(bool active);

  // Defaults to the bundled IDLE_TIMEOUT_SECONDS (or 60); changes from the
  // settings page or RemoteAdmin are saved to QSettings.
  int idleTimeoutSeconds() const noexcept { return idle_timeout_seconds_; }
  void setIdleTimeoutSeconds(int seconds);

  // Mirrors HassAPI.connected, kept in sync from QML (Main.qml) via a
  // Connections block -- RemoteAdmin needs this from C++, but HassAPI has no
  // reliable static accessor of its own (unlike Controler/RemoteAdmin, it's
  // only ever meant to be reached through QML).
  bool hassConnected() const noexcept { return hass_connected_; }
  void setHassConnected(bool connected);

  // Remote Admin (RemoteAdmin) config, from the bundled config -- empty
  // password means the server never starts listening, see remoteadmin.cpp.
  QString remoteAdminPassword() const { return bundledValue("REMOTE_ADMIN_PASSWORD"); }
  int remoteAdminPort() const { return bundledInt("REMOTE_ADMIN_PORT", 2323); }

  // MqttPublisher config -- empty host means it never connects, same gating
  // pattern as remoteAdminPassword() above. See mqttpublisher.cpp. Resolved
  // from the bundled MQTT_* keys, overridden by values saved from the
  // settings page; mqttConfigChanged() makes MqttPublisher reconnect.
  QString mqttBrokerHost() const noexcept { return mqtt_broker_host_; }
  int mqttBrokerPort() const noexcept { return mqtt_broker_port_; }
  QString mqttUsername() const noexcept { return mqtt_username_; }
  QString mqttPassword() const noexcept { return mqtt_password_; }
  // Saves all four at once, so MqttPublisher reconnects only once.
  Q_INVOKABLE void setMqttConfig(const QString &host, int port,
                                 const QString &username,
                                 const QString &password);
  // Forgets MQTT settings saved from the settings page, falling back to the
  // bundled config again.
  Q_INVOKABLE void clearSavedMqttConfig();

  static bool mqttSupported() noexcept;
  bool mqttConnected() const noexcept { return mqtt_connected_; }
  void setMqttConnected(bool connected);

  // A stable id for this device, shared by RemoteAdmin's deviceInfo
  // (deviceID/Mac) and MqttPublisher's MQTT topic/client id -- the first
  // non-loopback interface's hardware address, or a locally-administered
  // placeholder if none is found (sandboxed/virtual environment).
  QString deviceId() const;
  // The machine's host name, or "qthomeassistant" if it has none. RemoteAdmin
  // reports it as deviceInfo's deviceName.
  QString deviceName() const;
  // Non-loopback IPv4 addresses, in interface order.
  QStringList ipAddresses() const;
  // The first of ipAddresses(), or 127.0.0.1 -- RemoteAdmin's deviceInfo ip4.
  QString deviceIp() const;

  // Snapshot for the settings page's About section: name, ipAddresses, mac,
  // appVersion, system, qtVersion, remoteAdminEnabled, remoteAdminPort. A
  // call rather than properties since addresses can change while running.
  Q_INVOKABLE QVariantMap systemInfo() const;

protected:
  bool eventFilter(QObject *obj, QEvent *event) override;

signals:

  void hassUrlChanged();
  void hassTokenChanged();
  void screensaverActiveChanged();
  void idleTimeoutSecondsChanged();
  void hassConnectedChanged();
  void mqttConfigChanged();
  void mqttConnectedChanged();

  void requestDetails(QString entity_id, QString friendly_name);
  void configurationChanged(QVariant configuration);

  void error(QString);

  // HassAPI
  //
  void hassApiRequestDataUpdated(QString entity_id, QVariant data);

private:
  // Reads the bundled :/qt-hass/config (KEY=VALUE per line) into
  // bundled_config_.
  void loadConfig();
  void loadConnection();
  void loadMqttConfig();

  QString bundledValue(const QString &key) const {
    return bundled_config_.value(key);
  }
  int bundledInt(const QString &key, int fallback) const;

  static Controler *s_instance;

  bool has_user_interaction_;
  bool screensaver_active_{false};
  bool hass_connected_{false};
  bool mqtt_connected_{false};
  int idle_timeout_seconds_{60};
  QTimer is_idle_timer_;
  QHash<QString, QString> bundled_config_;
  QString hass_url_;
  QString hass_token_;
  QString mqtt_broker_host_;
  int mqtt_broker_port_{1883};
  QString mqtt_username_;
  QString mqtt_password_;
};

#endif // !CONTROLLER
