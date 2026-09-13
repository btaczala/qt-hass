#include "controller.h"

#include <QtCore/QDateTime>
#include <QtCore/QDir>
#include <QtCore/QEvent>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QStandardPaths>
#include <QtCore/QTextStream>
#include <QtCore/QtDebug>
#include <QtNetwork/QNetworkInterface>

#include <QtCore/qloggingcategory.h>
#include <chrono>
#include <filesystem>

Q_LOGGING_CATEGORY(controller, "qthass.controller")

Controler *Controler::s_instance = nullptr;
namespace {
const auto kDefaultIdleTimeout = std::chrono::seconds(60);
const std::vector<std::filesystem::path> kPossibleConfigPaths{
    std::filesystem::path{std::filesystem::current_path() /
                          std::filesystem::path{"config"}},
    std::filesystem::path{SOURCE_DIRECTORY / std::filesystem::path{"config"}},
    // Scoped storage means an Android app can't open arbitrary /sdcard paths
    // (e.g. /sdcard/qt-hass/config) without the user granting "All files
    // access" in Settings, so this uses the app-specific external directory
    // instead, which needs no permission at all.
    std::filesystem::path{
        QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
            .toStdString()} /
        "qt-hass" / "config"};

} // namespace

Controler::Controler(QObject *parent)
    : QObject(parent), has_user_interaction_(false),
      idle_timeout_seconds_(
          std::chrono::duration_cast<std::chrono::seconds>(kDefaultIdleTimeout)
              .count()) {

  is_idle_timer_.setInterval(
      std::chrono::duration_cast<std::chrono::milliseconds>(kDefaultIdleTimeout)
          .count());
  connect(&is_idle_timer_, &QTimer::timeout, this,
          [this]() { setScreensaverActive(true); });

  connect(
      &configuration_file_watcher_, &QFileSystemWatcher::fileChanged,
      [this](const QString &filePath) { loadConfig(filePath.toStdString()); });

  is_idle_timer_.start();
  is_idle_timer_.setSingleShot(true);

  // exists() alone isn't a reliable filter: on Android, cwd is "/" and
  // "/config" is the (permission-denied) configfs mount, which exists but
  // can never be opened -- so try each candidate in turn instead of trusting
  // the first one that merely exists().
  const auto config_it = std::ranges::find_if(
      kPossibleConfigPaths,
      [this](const std::filesystem::path &path) { return loadConfig(path); });
  if (config_it != std::end(kPossibleConfigPaths))
    configuration_file_watcher_.addPath(
        QString::fromStdString(config_it->string()));
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
  if (idle_timeout_seconds_ == seconds)
    return;
  applyIdleTimeoutSeconds(seconds);
  saveConfig();
}

void Controler::applyIdleTimeoutSeconds(int seconds) {
  idle_timeout_seconds_ = seconds;
  is_idle_timer_.setInterval(
      std::chrono::duration_cast<std::chrono::milliseconds>(
          std::chrono::seconds(seconds))
          .count());
  if (!screensaver_active_)
    is_idle_timer_.start();

  Q_EMIT idleTimeoutSecondsChanged();
}

bool Controler::loadConfig(const std::filesystem::path &path) {
  QFile file(QString::fromStdString(path.string()));
  if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
    qCWarning(controller) << "Could not open config file" << file.fileName();
    return false;
  }

  while (!file.atEnd()) {
    const QByteArray line = file.readLine().trimmed();
    if (line.isEmpty() || line.startsWith('#'))
      continue;

    const auto separator = line.indexOf('=');
    if (separator < 0)
      continue;

    const QByteArray key = line.first(separator).trimmed();
    const QByteArray value = line.sliced(separator + 1).trimmed();
    if (key == "HASS_URL")
      hass_url_ = QString::fromUtf8(value);
    else if (key == "HASS_TOKEN")
      hass_token_ = QString::fromUtf8(value);
    else if (key == "IDLE_TIMEOUT_SECONDS") {
      bool ok = false;
      const int seconds = value.toInt(&ok);
      if (ok)
        applyIdleTimeoutSeconds(seconds);
    } else if (key == "REMOTE_ADMIN_PASSWORD")
      remote_admin_password_ = QString::fromUtf8(value);
    else if (key == "REMOTE_ADMIN_PORT") {
      bool ok = false;
      const int port = value.toInt(&ok);
      if (ok)
        remote_admin_port_ = port;
    } else if (key == "MQTT_BROKER_HOST")
      mqtt_broker_host_ = QString::fromUtf8(value);
    else if (key == "MQTT_BROKER_PORT") {
      bool ok = false;
      const int port = value.toInt(&ok);
      if (ok)
        mqtt_broker_port_ = port;
    } else if (key == "MQTT_USERNAME")
      mqtt_username_ = QString::fromUtf8(value);
    else if (key == "MQTT_PASSWORD")
      mqtt_password_ = QString::fromUtf8(value);
  }

  configuration_path_ = QString::fromStdString(path.string());
  qCInfo(controller()) << configuration_path_;
  Q_EMIT configurationPathChanged();
  return true;
}

void Controler::saveConfig() {
  if (configuration_path_.isEmpty()) {
    // No config file was ever found -- create one so settings have
    // somewhere to persist. hass_url_/hass_token_ are empty in this case
    // too (nothing populated them), so this writes them out as blank; that's
    // fine, since a blank HASS_URL/HASS_TOKEN here just means the previous
    // state (no config file at all) is preserved for those two keys.
    const auto path = std::filesystem::path{
        QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
            .toStdString()} /
        "qt-hass" / "config";
    QDir{}.mkpath(QString::fromStdString(path.parent_path().string()));
    configuration_path_ = QString::fromStdString(path.string());
    configuration_file_watcher_.addPath(configuration_path_);
  }

  QFile file(configuration_path_);
  if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
    qCWarning(controller) << "Could not write config file" << file.fileName();
    return;
  }

  QTextStream out(&file);
  if (!hass_url_.isEmpty())
    out << "HASS_URL=" << hass_url_ << "\n";
  if (!hass_token_.isEmpty())
    out << "HASS_TOKEN=" << hass_token_ << "\n";
  out << "IDLE_TIMEOUT_SECONDS=" << idle_timeout_seconds_ << "\n";
  if (!remote_admin_password_.isEmpty())
    out << "REMOTE_ADMIN_PASSWORD=" << remote_admin_password_ << "\n";
  out << "REMOTE_ADMIN_PORT=" << remote_admin_port_ << "\n";
  if (!mqtt_broker_host_.isEmpty()) {
    out << "MQTT_BROKER_HOST=" << mqtt_broker_host_ << "\n";
    out << "MQTT_BROKER_PORT=" << mqtt_broker_port_ << "\n";
  }
  if (!mqtt_username_.isEmpty())
    out << "MQTT_USERNAME=" << mqtt_username_ << "\n";
  if (!mqtt_password_.isEmpty())
    out << "MQTT_PASSWORD=" << mqtt_password_ << "\n";
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

QUrl Controler::pathFor(const QString &config_path) {
  const std::vector<std::filesystem::path> possibleRootPaths{
      SOURCE_DIRECTORY, "/usr/share/qt-hass", "/sdcard/qt-hass"};

  auto file_it = std::ranges::find_if(
      possibleRootPaths, [config_path](const std::filesystem::path &path) {
        return std::filesystem::exists(path / config_path.toStdString());
      });

  if (file_it == std::end(possibleRootPaths)) {
    emit error(QString{"File %1 does not exists"}.arg(config_path));
    return QUrl{};
  }

  return QUrl::fromLocalFile(
      QString::fromStdString(*file_it / config_path.toStdString()));
}
