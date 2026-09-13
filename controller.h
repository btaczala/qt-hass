#ifndef CONTROLLER
#define CONTROLLER

#include <QtCore/QFileSystemWatcher>
#include <QtCore/QObject>
#include <QtCore/QTimer>
#include <QtCore/QVariant>
#include <QtCore/QUrl>
#include <QtQml/qqmlregistration.h>

#include <filesystem>

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
  Q_PROPERTY(QString configurationPath READ configurationPath NOTIFY
                 configurationPathChanged);
  Q_PROPERTY(bool screensaverActive READ screensaverActive WRITE
                 setScreensaverActive NOTIFY screensaverActiveChanged);
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

  QString configurationPath() const noexcept { return configuration_path_; }

  // The sole source of HASS_URL/HASS_TOKEN on every platform -- there is no
  // environment-variable fallback (hassapi.cpp's defaultUrl()/
  // defaultAccessToken() read these directly). Populated from the first
  // config file found among the paths loadConfig() searches, in KEY=VALUE
  // form.
  QString hassUrl() const noexcept { return hass_url_; }
  QString hassToken() const noexcept { return hass_token_; }

  bool screensaverActive() const noexcept { return screensaver_active_; }
  void setScreensaverActive(bool active);

  int idleTimeoutSeconds() const noexcept { return idle_timeout_seconds_; }
  void setIdleTimeoutSeconds(int seconds);

  // Mirrors HassAPI.connected, kept in sync from QML (Main.qml) via a
  // Connections block -- RemoteAdmin needs this from C++, but HassAPI has no
  // reliable static accessor of its own (unlike Controler/RemoteAdmin, it's
  // only ever meant to be reached through QML).
  bool hassConnected() const noexcept { return hass_connected_; }
  void setHassConnected(bool connected);

  // Remote Admin (RemoteAdmin) config -- empty password means the server
  // never starts listening, see remoteadmin.cpp.
  QString remoteAdminPassword() const noexcept { return remote_admin_password_; }
  int remoteAdminPort() const noexcept { return remote_admin_port_; }

  // MqttPublisher config -- empty host means it never connects, same gating
  // pattern as remoteAdminPassword() above. See mqttpublisher.cpp.
  QString mqttBrokerHost() const noexcept { return mqtt_broker_host_; }
  int mqttBrokerPort() const noexcept { return mqtt_broker_port_; }
  QString mqttUsername() const noexcept { return mqtt_username_; }
  QString mqttPassword() const noexcept { return mqtt_password_; }

  // A stable id for this device, shared by RemoteAdmin's deviceInfo
  // (deviceID/Mac) and MqttPublisher's MQTT topic/client id -- the first
  // non-loopback interface's hardware address, or a locally-administered
  // placeholder if none is found (sandboxed/virtual environment).
  QString deviceId() const;

  Q_INVOKABLE QUrl pathFor(const QString& file);

protected:
  bool eventFilter(QObject *obj, QEvent *event) override;

signals:

  void configurationPathChanged();

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
  // Returns false (after logging a warning) if `path` couldn't be opened.
  bool loadConfig(const std::filesystem::path &path);
  // Writes HASS_URL/HASS_TOKEN and the settings keys below back to
  // configuration_path_, falling back to AppDataLocation/qt-hass/config if
  // no config file was ever found (e.g. on desktop, where HASS_URL/TOKEN
  // normally come from the environment and no config file exists at all).
  void saveConfig();
  // Applies a new idle timeout (field + timer + notify) without persisting
  // it -- used by loadConfig() so reading a value back out of the config
  // file doesn't turn around and write to that same file while it's still
  // open for reading. setIdleTimeoutSeconds() is the persisting, public
  // entry point (used by RemoteAdmin).
  void applyIdleTimeoutSeconds(int seconds);

  static Controler *s_instance;

  bool has_user_interaction_;
  bool screensaver_active_{false};
  bool hass_connected_{false};
  int idle_timeout_seconds_;
  QTimer is_idle_timer_;
  QFileSystemWatcher configuration_file_watcher_;
  QString configuration_path_;
  QString hass_url_;
  QString hass_token_;
  QString remote_admin_password_;
  int remote_admin_port_{2323};
  QString mqtt_broker_host_;
  int mqtt_broker_port_{1883};
  QString mqtt_username_;
  QString mqtt_password_;
};

#endif // !CONTROLLER
