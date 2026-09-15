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
  // The dashboard's root QML file, from dashboardSource; empty means none is
  // defined.
  Q_PROPERTY(QString dashboardUrl READ dashboardUrl NOTIFY dashboardUrlChanged)
  // Where the dashboard comes from: "url" for customDashboardUrl, or "hass"
  // for dashboardConfig in Home Assistant's www folder (hassDashboardsUrl).
  Q_PROPERTY(QString dashboardSource READ dashboardSource WRITE
                 setDashboardSource NOTIFY dashboardSourceChanged)
  Q_PROPERTY(QString customDashboardUrl READ customDashboardUrl WRITE
                 setCustomDashboardUrl NOTIFY dashboardSourceChanged)
  // A directory of /config/www/qthass/ holding a main.qml.
  Q_PROPERTY(QString dashboardConfig READ dashboardConfig WRITE
                 setDashboardConfig NOTIFY dashboardSourceChanged)
  // Home Assistant's /config/www/qthass/ over HTTP, from hassUrl; empty
  // without a usable hassUrl.
  Q_PROPERTY(
      QString hassDashboardsUrl READ hassDashboardsUrl NOTIFY hassUrlChanged)
  Q_PROPERTY(bool screensaverActive READ screensaverActive WRITE
                 setScreensaverActive NOTIFY screensaverActiveChanged);
  // Seconds without user input before the screensaver starts; 0 means never.
  Q_PROPERTY(int idleTimeoutSeconds READ idleTimeoutSeconds WRITE
                 setIdleTimeoutSeconds NOTIFY idleTimeoutSecondsChanged);
  Q_PROPERTY(bool hassConnected READ hassConnected WRITE setHassConnected
                 NOTIFY hassConnectedChanged);
  // Keeps the display from turning off while the app is in front, like the
  // HA companion app's "Keep screen on". Only does anything on Android.
  Q_PROPERTY(bool keepScreenOn READ keepScreenOn WRITE setKeepScreenOn NOTIFY
                 keepScreenOnChanged)
  Q_PROPERTY(bool keepScreenOnSupported READ keepScreenOnSupported CONSTANT)
  Q_PROPERTY(int batteryLevel READ batteryLevel NOTIFY batteryChanged)
  Q_PROPERTY(bool batteryCharging READ batteryCharging NOTIFY batteryChanged)
  Q_PROPERTY(bool batterySupported READ batterySupported CONSTANT)
  Q_PROPERTY(QString mqttBrokerHost READ mqttBrokerHost NOTIFY mqttConfigChanged)
  Q_PROPERTY(int mqttBrokerPort READ mqttBrokerPort NOTIFY mqttConfigChanged)
  Q_PROPERTY(QString mqttUsername READ mqttUsername NOTIFY mqttConfigChanged)
  Q_PROPERTY(QString mqttPassword READ mqttPassword NOTIFY mqttConfigChanged)
  // Whether this build has Qt MQTT at all (MqttPublisher compiled in).
  Q_PROPERTY(bool mqttSupported READ mqttSupported CONSTANT)
  // Whether this build has AnimatedBackground's dithering shader.
  Q_PROPERTY(bool backgroundShaderSupported READ backgroundShaderSupported CONSTANT)
  // Set by MqttPublisher; always false without mqttSupported.
  Q_PROPERTY(bool mqttConnected READ mqttConnected NOTIFY mqttConnectedChanged)
  // Whether the first-run setup (qml/Setup/SetupWizard.qml) has been
  // finished; saved to QSettings. Until first saved, true exactly when a
  // token was already configured at startup.
  Q_PROPERTY(bool setupCompleted READ setupCompleted WRITE setSetupCompleted
                 NOTIFY setupCompletedChanged)
  // Name this device goes by: RemoteAdmin's deviceInfo, the long-lived token
  // created at setup. Saved to QSettings; empty resets it to the host name.
  Q_PROPERTY(QString deviceName READ deviceName WRITE setDeviceName NOTIFY
                 deviceNameChanged)
  Q_PROPERTY(bool remoteAdminEnabled READ remoteAdminEnabled NOTIFY
                 remoteAdminConfigChanged)
  Q_PROPERTY(QString remoteAdminPassword READ remoteAdminPassword NOTIFY
                 remoteAdminConfigChanged)
  Q_PROPERTY(int remoteAdminPort READ remoteAdminPort NOTIFY
                 remoteAdminConfigChanged)

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

  QString dashboardUrl() const noexcept { return dashboard_url_; }
  QString dashboardSource() const noexcept { return dashboard_source_; }
  void setDashboardSource(const QString &source);
  // The bundled DASHBOARD_URL, overridden by a URL saved from the settings
  // page. Saving an empty URL forgets the saved one.
  QString customDashboardUrl() const noexcept { return custom_dashboard_url_; }
  void setCustomDashboardUrl(const QString &url);
  QString dashboardConfig() const noexcept { return dashboard_config_; }
  void setDashboardConfig(const QString &config);
  QString hassDashboardsUrl() const;

  bool screensaverActive() const noexcept { return screensaver_active_; }
  void setScreensaverActive(bool active);

  // Defaults to the bundled IDLE_TIMEOUT_SECONDS (or 60); changes from the
  // settings page or RemoteAdmin are saved to QSettings. 0 disables the
  // screensaver, matching Fully Kiosk's timeToScreensaverV2.
  int idleTimeoutSeconds() const noexcept { return idle_timeout_seconds_; }
  void setIdleTimeoutSeconds(int seconds);

  // Mirrors HassAPI.connected, kept in sync from QML (Main.qml) via a
  // Connections block -- RemoteAdmin needs this from C++, but HassAPI has no
  // reliable static accessor of its own (unlike Controler/RemoteAdmin, it's
  // only ever meant to be reached through QML).
  bool hassConnected() const noexcept { return hass_connected_; }
  void setHassConnected(bool connected);

  // Saved to QSettings; off by default. On Android, sets or clears the
  // activity window's FLAG_KEEP_SCREEN_ON.
  bool keepScreenOn() const noexcept { return keep_screen_on_; }
  void setKeepScreenOn(bool on);
  static bool keepScreenOnSupported() noexcept;

  // This device's battery, polled on Android only: level in percent (-1 while
  // unknown, and always off Android) and whether it's on external power.
  int batteryLevel() const noexcept { return battery_level_; }
  bool batteryCharging() const noexcept { return battery_charging_; }
  static bool batterySupported() noexcept;

  // Remote Admin (RemoteAdmin) config: the bundled REMOTE_ADMIN_* keys,
  // overridden by values saved at setup. The server only listens while
  // enabled with a non-empty password, see remoteadmin.cpp. Enabled by default
  // exactly when the bundle has a password.
  bool remoteAdminEnabled() const;
  QString remoteAdminPassword() const;
  int remoteAdminPort() const;
  // Saves all three at once; remoteAdminConfigChanged() restarts the server.
  Q_INVOKABLE void setRemoteAdminConfig(bool enabled, const QString &password,
                                        int port);

  bool setupCompleted() const noexcept { return setup_completed_; }
  void setSetupCompleted(bool completed);

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
  static bool backgroundShaderSupported() noexcept;
  bool mqttConnected() const noexcept { return mqtt_connected_; }
  void setMqttConnected(bool connected);

  // A stable id for this device, shared by RemoteAdmin's deviceInfo
  // (deviceID/Mac) and MqttPublisher's MQTT topic/client id -- the first
  // non-loopback interface's hardware address, or a locally-administered
  // placeholder if none is found (sandboxed/virtual environment).
  QString deviceId() const;
  // The name saved at setup, else the machine's host name, or
  // "qthomeassistant" if it has none.
  QString deviceName() const;
  void setDeviceName(const QString &name);
  // What deviceName falls back to when none is saved.
  Q_INVOKABLE QString hostName() const;
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
  void dashboardUrlChanged();
  void dashboardSourceChanged();
  void screensaverActiveChanged();
  void idleTimeoutSecondsChanged();
  void hassConnectedChanged();
  void keepScreenOnChanged();
  void batteryChanged();
  void mqttConfigChanged();
  void mqttConnectedChanged();
  void setupCompletedChanged();
  void deviceNameChanged();
  void remoteAdminConfigChanged();

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
  // Applies keep_screen_on_ to the Android activity window; a no-op elsewhere.
  void applyKeepScreenOn() const;
  // Reads the battery into battery_level_/battery_charging_; a no-op off
  // Android.
  void updateBattery();

  QString bundledValue(const QString &key) const {
    return bundled_config_.value(key);
  }
  int bundledInt(const QString &key, int fallback) const;

  static Controler *s_instance;

  bool has_user_interaction_;
  bool screensaver_active_{false};
  bool hass_connected_{false};
  bool mqtt_connected_{false};
  bool keep_screen_on_{false};
  bool setup_completed_{false};
  int idle_timeout_seconds_{60};
  QTimer is_idle_timer_;
  int battery_level_{-1};
  bool battery_charging_{false};
  QTimer battery_timer_;
  QHash<QString, QString> bundled_config_;
  QString hass_url_;
  QString hass_token_;
  // Recomputes dashboard_url_ from the source, emitting dashboardUrlChanged
  // when it changed.
  void updateDashboardUrl();

  QString dashboard_url_;
  QString dashboard_source_;
  QString custom_dashboard_url_;
  QString dashboard_config_;
  QString mqtt_broker_host_;
  int mqtt_broker_port_{1883};
  QString mqtt_username_;
  QString mqtt_password_;
};

#endif // !CONTROLLER
