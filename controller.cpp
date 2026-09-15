#include "controller.h"

#include <QtCore/QEvent>
#include <QtCore/QFile>
#include <QtCore/QSettings>
#include <QtCore/QSysInfo>
#include <QtCore/QUrl>
#include <QtCore/QtDebug>
#include <QtNetwork/QNetworkInterface>

#ifdef Q_OS_ANDROID
#include <QtCore/QCoreApplication>
#include <QtCore/QJniObject>
#endif

#include <QtCore/qloggingcategory.h>
#include <chrono>

Q_LOGGING_CATEGORY(controller, "qthass.controller")

Controler *Controler::s_instance = nullptr;
namespace {
const auto kDefaultIdleTimeout = std::chrono::seconds(60);
// Quick enough that plugging in shows up soon; the read is a single binder call.
const auto kBatteryPollInterval = std::chrono::seconds(5);
const auto kConfigPath = QStringLiteral(":/qt-hass/config");

const auto kHassUrlKey = QStringLiteral("connection/url");
const auto kHassTokenKey = QStringLiteral("connection/token");
const auto kDashboardUrlKey = QStringLiteral("dashboard/url");
const auto kDashboardSourceKey = QStringLiteral("dashboard/source");
const auto kDashboardConfigKey = QStringLiteral("dashboard/config");
const auto kDashboardSourceHass = QStringLiteral("hass");
const auto kDashboardSourceUrl = QStringLiteral("url");
const auto kIdleTimeoutKey = QStringLiteral("idleTimeout");
const auto kKeepScreenOnKey = QStringLiteral("display/keepScreenOn");
const auto kMqttHostKey = QStringLiteral("mqtt/host");
const auto kMqttPortKey = QStringLiteral("mqtt/port");
const auto kMqttUsernameKey = QStringLiteral("mqtt/username");
const auto kMqttPasswordKey = QStringLiteral("mqtt/password");
const auto kDefaultMqttPort = 1883;
const auto kSetupCompletedKey = QStringLiteral("setup/completed");
const auto kDeviceNameKey = QStringLiteral("device/name");
const auto kRemoteAdminEnabledKey = QStringLiteral("remoteAdmin/enabled");
const auto kRemoteAdminPasswordKey = QStringLiteral("remoteAdmin/password");
const auto kRemoteAdminPortKey = QStringLiteral("remoteAdmin/port");
const auto kDefaultRemoteAdminPort = 2323;
} // namespace

Controler::Controler(QObject *parent)
    : QObject(parent), has_user_interaction_(false) {
  // The QML engine constructs its singleton with this constructor, not with
  // create() (main.cpp resolves it before anything else), so that first
  // instance has to become the one create()/instance() hand out -- otherwise
  // HassAPI reads a second instance that never sees changes made from QML.
  if (!s_instance)
    s_instance = this;

  loadConfig();

  idle_timeout_seconds_ =
      QSettings{}
          .value(kIdleTimeoutKey,
                 bundledInt("IDLE_TIMEOUT_SECONDS",
                            int(kDefaultIdleTimeout.count())))
          .toInt();
  is_idle_timer_.setInterval(std::chrono::seconds(idle_timeout_seconds_));
  connect(&is_idle_timer_, &QTimer::timeout, this,
          [this]() { setScreensaverActive(true); });

  is_idle_timer_.setSingleShot(true);
  if (idle_timeout_seconds_ > 0)
    is_idle_timer_.start();

  loadConnection();
  loadMqttConfig();
  {
    const QSettings settings;
    dashboard_source_ =
        settings.value(kDashboardSourceKey, kDashboardSourceUrl).toString();
    custom_dashboard_url_ =
        settings.value(kDashboardUrlKey, bundledValue("DASHBOARD_URL"))
            .toString();
    dashboard_config_ = settings.value(kDashboardConfigKey).toString();
  }
  updateDashboardUrl();
  // The Home Assistant www URL follows the connection's.
  connect(this, &Controler::hassUrlChanged, this,
          &Controler::updateDashboardUrl);

  // Never saved: an install that already has a token (bundled, environment
  // or saved from the settings page) is set up; only one without runs setup.
  // Decided once here, since the wizard itself changes the token.
  setup_completed_ =
      QSettings{}.value(kSetupCompletedKey, !hass_token_.isEmpty()).toBool();

  keep_screen_on_ = QSettings{}.value(kKeepScreenOnKey, false).toBool();
  applyKeepScreenOn();

  if (batterySupported()) {
    battery_timer_.setInterval(kBatteryPollInterval);
    connect(&battery_timer_, &QTimer::timeout, this,
            &Controler::updateBattery);
    battery_timer_.start();
    updateBattery();
  }
}

void Controler::setKeepScreenOn(bool on) {
  if (keep_screen_on_ == on)
    return;
  keep_screen_on_ = on;
  QSettings{}.setValue(kKeepScreenOnKey, on);
  applyKeepScreenOn();
  Q_EMIT keepScreenOnChanged();
}

bool Controler::keepScreenOnSupported() noexcept {
#ifdef Q_OS_ANDROID
  return true;
#else
  return false;
#endif
}

void Controler::applyKeepScreenOn() const {
#ifdef Q_OS_ANDROID
  // Window flags may only be changed from the Android UI thread, not Qt's.
  QNativeInterface::QAndroidApplication::runOnAndroidMainThread(
      [on = keep_screen_on_]() {
        // android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        constexpr jint kFlagKeepScreenOn = 0x00000080;
        const QJniObject activity =
            QNativeInterface::QAndroidApplication::context();
        const QJniObject window =
            activity.callObjectMethod("getWindow", "()Landroid/view/Window;");
        if (!window.isValid()) {
          qCWarning(controller) << "No activity window to keep the screen on";
          return;
        }
        window.callMethod<void>(on ? "addFlags" : "clearFlags", "(I)V",
                                kFlagKeepScreenOn);
      });
#endif
}

bool Controler::batterySupported() noexcept {
#ifdef Q_OS_ANDROID
  return true;
#else
  return false;
#endif
}

void Controler::updateBattery() {
#ifdef Q_OS_ANDROID
  // ACTION_BATTERY_CHANGED is sticky: registering a null receiver just returns
  // the last broadcast, with level, charge status and power source in one go.
  // Preferred over BatteryManager.getIntProperty(), which returns garbage on
  // some older devices.
  const QJniObject context = QNativeInterface::QAndroidApplication::context();
  const QJniObject filter = QJniObject(
      "android/content/IntentFilter", "(Ljava/lang/String;)V",
      QJniObject::fromString(
          QStringLiteral("android.intent.action.BATTERY_CHANGED"))
          .object<jstring>());
  const QJniObject intent = context.callObjectMethod(
      "registerReceiver",
      "(Landroid/content/BroadcastReceiver;Landroid/content/IntentFilter;)"
      "Landroid/content/Intent;",
      jobject(nullptr), filter.object());
  if (!intent.isValid()) {
    qCWarning(controller) << "No battery status available";
    return;
  }

  const auto extra = [&intent](const char *name, jint fallback) {
    return intent.callMethod<jint>(
        "getIntExtra", "(Ljava/lang/String;I)I",
        QJniObject::fromString(QString::fromLatin1(name)).object<jstring>(),
        fallback);
  };
  const jint level = extra("level", -1);
  const jint scale = extra("scale", 100);
  // BatteryManager.BATTERY_STATUS_CHARGING / BATTERY_STATUS_FULL
  const jint status = extra("status", -1);
  const jint plugged = extra("plugged", 0);

  const int percent =
      level >= 0 && scale > 0 ? qRound(100.0 * level / scale) : -1;
  // Plugged in counts too: a wall-mounted tablet held at a charge limit
  // reports "not charging" while on power.
  const bool charging = status == 2 || status == 5 || plugged != 0;
  if (percent == battery_level_ && charging == battery_charging_)
    return;
  battery_level_ = percent;
  battery_charging_ = charging;
  Q_EMIT batteryChanged();
#endif
}

void Controler::loadMqttConfig() {
  const QSettings settings;
  mqtt_broker_host_ =
      settings.value(kMqttHostKey, bundledValue("MQTT_BROKER_HOST")).toString();
  mqtt_broker_port_ =
      settings
          .value(kMqttPortKey, bundledInt("MQTT_BROKER_PORT", kDefaultMqttPort))
          .toInt();
  mqtt_username_ =
      settings.value(kMqttUsernameKey, bundledValue("MQTT_USERNAME")).toString();
  mqtt_password_ =
      settings.value(kMqttPasswordKey, bundledValue("MQTT_PASSWORD")).toString();
}

void Controler::setMqttConfig(const QString &host, int port,
                              const QString &username,
                              const QString &password) {
  if (port <= 0 || port > 65535)
    port = kDefaultMqttPort;
  if (host == mqtt_broker_host_ && port == mqtt_broker_port_ &&
      username == mqtt_username_ && password == mqtt_password_)
    return;

  QSettings settings;
  settings.setValue(kMqttHostKey, host);
  settings.setValue(kMqttPortKey, port);
  settings.setValue(kMqttUsernameKey, username);
  settings.setValue(kMqttPasswordKey, password);
  loadMqttConfig();
  Q_EMIT mqttConfigChanged();
}

void Controler::clearSavedMqttConfig() {
  QSettings settings;
  settings.remove(kMqttHostKey);
  settings.remove(kMqttPortKey);
  settings.remove(kMqttUsernameKey);
  settings.remove(kMqttPasswordKey);
  loadMqttConfig();
  Q_EMIT mqttConfigChanged();
}

bool Controler::mqttSupported() noexcept {
#ifdef QTHASS_HAS_MQTT
  return true;
#else
  return false;
#endif
}

bool Controler::backgroundShaderSupported() noexcept {
#ifdef QTHASS_HAS_SHADERS
  return true;
#else
  return false;
#endif
}

void Controler::setMqttConnected(bool connected) {
  if (mqtt_connected_ == connected)
    return;
  mqtt_connected_ = connected;
  Q_EMIT mqttConnectedChanged();
}

void Controler::loadConnection() {
  const QString old_url = hass_url_;
  const QString old_token = hass_token_;
  hass_url_ = bundledValue("HASS_URL");
  hass_token_ = bundledValue("HASS_TOKEN");

  // qEnvironmentVariable() finds nothing on Android, which has no process
  // environment to inherit these from -- the bundled config covers that.
  if (const QString url = qEnvironmentVariable("HASS_URL"); !url.isEmpty())
    hass_url_ = url;
  if (const QString token = qEnvironmentVariable("HASS_TOKEN");
      !token.isEmpty())
    hass_token_ = token;

  const QSettings settings;
  hass_url_ = settings.value(kHassUrlKey, hass_url_).toString();
  hass_token_ = settings.value(kHassTokenKey, hass_token_).toString();

  if (hass_url_ != old_url)
    Q_EMIT hassUrlChanged();
  if (hass_token_ != old_token)
    Q_EMIT hassTokenChanged();
}

void Controler::clearSavedConnection() {
  QSettings settings;
  settings.remove(kHassUrlKey);
  settings.remove(kHassTokenKey);
  loadConnection();
}

void Controler::setHassUrl(const QString &url) {
  if (url == hass_url_)
    return;
  hass_url_ = url;
  QSettings{}.setValue(kHassUrlKey, url);
  Q_EMIT hassUrlChanged();
}

void Controler::setHassToken(const QString &token) {
  if (token == hass_token_)
    return;
  hass_token_ = token;
  QSettings{}.setValue(kHassTokenKey, token);
  Q_EMIT hassTokenChanged();
}

void Controler::setDashboardSource(const QString &source) {
  const QString valid =
      source == kDashboardSourceHass ? kDashboardSourceHass : kDashboardSourceUrl;
  if (valid == dashboard_source_)
    return;
  dashboard_source_ = valid;
  QSettings{}.setValue(kDashboardSourceKey, valid);
  Q_EMIT dashboardSourceChanged();
  updateDashboardUrl();
}

void Controler::setCustomDashboardUrl(const QString &url) {
  QSettings settings;
  if (url.isEmpty())
    settings.remove(kDashboardUrlKey);
  else
    settings.setValue(kDashboardUrlKey, url);
  const QString resolved =
      settings.value(kDashboardUrlKey, bundledValue("DASHBOARD_URL"))
          .toString();
  if (resolved == custom_dashboard_url_)
    return;
  custom_dashboard_url_ = resolved;
  Q_EMIT dashboardSourceChanged();
  updateDashboardUrl();
}

void Controler::setDashboardConfig(const QString &config) {
  if (config == dashboard_config_)
    return;
  dashboard_config_ = config;
  QSettings{}.setValue(kDashboardConfigKey, config);
  Q_EMIT dashboardSourceChanged();
  updateDashboardUrl();
}

QString Controler::hassDashboardsUrl() const {
  QUrl url(hass_url_);
  if (url.scheme() == u"ws")
    url.setScheme(QStringLiteral("http"));
  else if (url.scheme() == u"wss")
    url.setScheme(QStringLiteral("https"));
  else if (url.scheme() != u"http" && url.scheme() != u"https")
    return {};
  if (url.host().isEmpty())
    return {};
  // Home Assistant serves /config/www/ at /local/.
  url.setPath(QStringLiteral("/local/qthass/"));
  url.setQuery(QString{});
  url.setFragment(QString{});
  return url.toString();
}

void Controler::updateDashboardUrl() {
  QString url = custom_dashboard_url_;
  if (dashboard_source_ == kDashboardSourceHass) {
    const QString base = hassDashboardsUrl();
    url = base.isEmpty() || dashboard_config_.isEmpty()
              ? QString{}
              : base + QString::fromUtf8(QUrl::toPercentEncoding(
                           dashboard_config_)) +
                    QStringLiteral("/main.qml");
  }
  if (url == dashboard_url_)
    return;
  dashboard_url_ = url;
  Q_EMIT dashboardUrlChanged();
}

void Controler::setScreensaverActive(bool active) {
  if (screensaver_active_ != active) {
    screensaver_active_ = active;
    Q_EMIT screensaverActiveChanged();
  }
  // Any explicit "off" -- whether from local interaction or a remote
  // stopScreensaver command -- rearms the countdown, since is_idle_timer_ is
  // single-shot and would otherwise never fire again.
  if (!active && idle_timeout_seconds_ > 0)
    is_idle_timer_.start();
}

void Controler::setHassConnected(bool connected) {
  if (hass_connected_ == connected)
    return;
  hass_connected_ = connected;
  Q_EMIT hassConnectedChanged();
}

void Controler::setIdleTimeoutSeconds(int seconds) {
  if (seconds < 0 || seconds == idle_timeout_seconds_)
    return;
  idle_timeout_seconds_ = seconds;
  if (seconds == 0) {
    is_idle_timer_.stop();
  } else {
    is_idle_timer_.setInterval(std::chrono::seconds(seconds));
    // The new timeout counts from now, unless the screensaver is already up.
    if (!screensaver_active_)
      is_idle_timer_.start();
  }
  QSettings{}.setValue(kIdleTimeoutKey, seconds);
  Q_EMIT idleTimeoutSecondsChanged();
}

bool Controler::eventFilter(QObject *obj, QEvent *event) {

  if (event->type() == QEvent::TouchBegin ||
      event->type() == QEvent::KeyPress ||
      event->type() == QEvent::MouseButtonPress ||
      event->type() == QEvent::MouseButtonDblClick) {
    setScreensaverActive(false);
    has_user_interaction_ = true;
  }

  return false;
}

void Controler::loadConfig() {
  QFile file(kConfigPath);
  if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
    qCWarning(controller) << "Could not open config file" << file.fileName();
    return;
  }

  while (!file.atEnd()) {
    const QByteArray line = file.readLine().trimmed();
    if (line.isEmpty() || line.startsWith('#'))
      continue;

    const auto separator = line.indexOf('=');
    if (separator < 0)
      continue;

    bundled_config_.insert(QString::fromUtf8(line.first(separator).trimmed()),
                           QString::fromUtf8(line.sliced(separator + 1).trimmed()));
  }
}

int Controler::bundledInt(const QString &key, int fallback) const {
  bool ok = false;
  const int value = bundled_config_.value(key).toInt(&ok);
  return ok ? value : fallback;
}

QString Controler::deviceId() const {
  for (const QNetworkInterface &iface : QNetworkInterface::allInterfaces()) {
    if (iface.flags().testFlag(QNetworkInterface::IsLoopBack))
      continue;
    const QString mac = iface.hardwareAddress();
    if (!mac.isEmpty() && mac != QLatin1String("00:00:00:00:00:00"))
      return mac;
  }
  // No real interface found (sandboxed/virtual environment) -- a
  // locally-administered placeholder so the id is still non-empty.
  return QStringLiteral("02:00:00:00:00:00");
}

QString Controler::hostName() const {
  const QString name = QSysInfo::machineHostName();
  return name.isEmpty() ? QStringLiteral("qthomeassistant") : name;
}

QString Controler::deviceName() const {
  const QString name = QSettings{}.value(kDeviceNameKey).toString();
  return name.isEmpty() ? hostName() : name;
}

void Controler::setDeviceName(const QString &name) {
  const QString old_name = deviceName();
  QSettings settings;
  if (name.trimmed().isEmpty())
    settings.remove(kDeviceNameKey);
  else
    settings.setValue(kDeviceNameKey, name.trimmed());
  if (deviceName() != old_name)
    Q_EMIT deviceNameChanged();
}

void Controler::setSetupCompleted(bool completed) {
  if (completed == setup_completed_)
    return;
  setup_completed_ = completed;
  QSettings{}.setValue(kSetupCompletedKey, completed);
  Q_EMIT setupCompletedChanged();
}

bool Controler::remoteAdminEnabled() const {
  return QSettings{}
      .value(kRemoteAdminEnabledKey,
             !bundledValue("REMOTE_ADMIN_PASSWORD").isEmpty())
      .toBool();
}

QString Controler::remoteAdminPassword() const {
  return QSettings{}
      .value(kRemoteAdminPasswordKey, bundledValue("REMOTE_ADMIN_PASSWORD"))
      .toString();
}

int Controler::remoteAdminPort() const {
  return QSettings{}
      .value(kRemoteAdminPortKey,
             bundledInt("REMOTE_ADMIN_PORT", kDefaultRemoteAdminPort))
      .toInt();
}

void Controler::setRemoteAdminConfig(bool enabled, const QString &password,
                                     int port) {
  if (port <= 0 || port > 65535)
    port = kDefaultRemoteAdminPort;
  if (enabled == remoteAdminEnabled() && password == remoteAdminPassword() &&
      port == remoteAdminPort())
    return;
  QSettings settings;
  settings.setValue(kRemoteAdminEnabledKey, enabled);
  settings.setValue(kRemoteAdminPasswordKey, password);
  settings.setValue(kRemoteAdminPortKey, port);
  Q_EMIT remoteAdminConfigChanged();
}

QStringList Controler::ipAddresses() const {
  QStringList addresses;
  for (const QHostAddress &address : QNetworkInterface::allAddresses()) {
    if (address.protocol() == QAbstractSocket::IPv4Protocol && !address.isLoopback())
      addresses << address.toString();
  }
  return addresses;
}

QString Controler::deviceIp() const {
  const QStringList addresses = ipAddresses();
  return addresses.isEmpty() ? QStringLiteral("127.0.0.1") : addresses.first();
}

QVariantMap Controler::systemInfo() const {
  return {
      {"name", deviceName()},
      {"ipAddresses", ipAddresses()},
      {"mac", deviceId()},
      {"appVersion", QStringLiteral(APP_VERSION)},
      {"system", QSysInfo::prettyProductName()},
      {"qtVersion", QString::fromLatin1(qVersion())},
      {"remoteAdminEnabled",
       remoteAdminEnabled() && !remoteAdminPassword().isEmpty()},
      {"remoteAdminPort", remoteAdminPort()},
  };
}
