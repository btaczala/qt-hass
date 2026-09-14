#ifndef CONTROLLER
#define CONTROLLER

#include <QtCore/QHash>
#include <QtCore/QObject>
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

  // MqttPublisher config, from the bundled config -- empty host means it
  // never connects, same gating pattern as remoteAdminPassword() above. See
  // mqttpublisher.cpp.
  QString mqttBrokerHost() const { return bundledValue("MQTT_BROKER_HOST"); }
  int mqttBrokerPort() const { return bundledInt("MQTT_BROKER_PORT", 1883); }
  QString mqttUsername() const { return bundledValue("MQTT_USERNAME"); }
  QString mqttPassword() const { return bundledValue("MQTT_PASSWORD"); }

  // A stable id for this device, shared by RemoteAdmin's deviceInfo
  // (deviceID/Mac) and MqttPublisher's MQTT topic/client id -- the first
  // non-loopback interface's hardware address, or a locally-administered
  // placeholder if none is found (sandboxed/virtual environment).
  QString deviceId() const;

protected:
  bool eventFilter(QObject *obj, QEvent *event) override;

signals:

  void hassUrlChanged();
  void hassTokenChanged();
  void screensaverActiveChanged();
  void idleTimeoutSecondsChanged();
  void hassConnectedChanged();

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

  QString bundledValue(const QString &key) const {
    return bundled_config_.value(key);
  }
  int bundledInt(const QString &key, int fallback) const;

  static Controler *s_instance;

  bool has_user_interaction_;
  bool screensaver_active_{false};
  bool hass_connected_{false};
  int idle_timeout_seconds_{60};
  QTimer is_idle_timer_;
  QHash<QString, QString> bundled_config_;
  QString hass_url_;
  QString hass_token_;
};

#endif // !CONTROLLER
