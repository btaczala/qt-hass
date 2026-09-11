#include "controller.h"

#include <QtCore/QDateTime>
#include <QtCore/QDir>
#include <QtCore/QEvent>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QStandardPaths>
#include <QtCore/QtDebug>

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
    : QObject(parent), has_user_interaction_(false) {

  is_idle_timer_.setInterval(
      std::chrono::duration_cast<std::chrono::milliseconds>(kDefaultIdleTimeout)
          .count());
  connect(&is_idle_timer_, &QTimer::timeout, this, [this]() {
    qDebug() << "idle";
    Q_EMIT idle(true);
  });

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
    Q_EMIT idle(false);
    is_idle_timer_.start();
    has_user_interaction_ = true;
  }

  return false;
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
  }

  configuration_path_ = QString::fromStdString(path.string());
  Q_EMIT configurationPathChanged();
  return true;
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
