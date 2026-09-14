#include "controller.h"

#include <QtCore/QEvent>
#include <QtCore/QFile>
#include <QtCore/QSettings>
#include <QtCore/QSysInfo>
#include <QtCore/QtDebug>
#include <QtNetwork/QNetworkInterface>

#include <QtCore/qloggingcategory.h>
#include <chrono>

Q_LOGGING_CATEGORY(controller, "qthass.controller")

Controler *Controler::s_instance = nullptr;
namespace {
const auto kDefaultIdleTimeout = std::chrono::seconds(60);
const auto kConfigPath = QStringLiteral(":/qt-hass/config");

const auto kHassUrlKey = QStringLiteral("connection/url");
const auto kHassTokenKey = QStringLiteral("connection/token");
const auto kIdleTimeoutKey = QStringLiteral("idleTimeout");
const auto kMqttHostKey = QStringLiteral("mqtt/host");
const auto kMqttPortKey = QStringLiteral("mqtt/port");
const auto kMqttUsernameKey = QStringLiteral("mqtt/username");
const auto kMqttPasswordKey = QStringLiteral("mqtt/password");
const auto kDefaultMqttPort = 1883;
} // namespace

Controler::Controler(QObject *parent)
    : QObject(parent), has_user_interaction_(false) {

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

  is_idle_timer_.start();
  is_idle_timer_.setSingleShot(true);

  loadConnection();
  loadMqttConfig();
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

void Controler::setScreensaverActive(bool active) {
  if (screensaver_active_ != active) {
    screensaver_active_ = active;
    Q_EMIT screensaverActiveChanged();
  }
  // Any explicit "off" -- whether from local interaction or a remote
  // stopScreensaver command -- rearms the countdown, since is_idle_timer_ is
  // single-shot and would otherwise never fire again.
  if (!active)
    is_idle_timer_.start();
}

void Controler::setHassConnected(bool connected) {
  if (hass_connected_ == connected)
    return;
  hass_connected_ = connected;
  Q_EMIT hassConnectedChanged();
}

void Controler::setIdleTimeoutSeconds(int seconds) {
  if (seconds <= 0 || seconds == idle_timeout_seconds_)
    return;
  idle_timeout_seconds_ = seconds;
  is_idle_timer_.setInterval(std::chrono::seconds(seconds));
  // The new timeout counts from now, unless the screensaver is already up.
  if (!screensaver_active_)
    is_idle_timer_.start();
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

QString Controler::deviceName() const {
  const QString name = QSysInfo::machineHostName();
  return name.isEmpty() ? QStringLiteral("qthomeassistant") : name;
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
      {"remoteAdminEnabled", !remoteAdminPassword().isEmpty()},
      {"remoteAdminPort", remoteAdminPort()},
  };
}
