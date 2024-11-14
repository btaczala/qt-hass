#include "controller.h"

#include <QtCore/QDateTime>
#include <QtCore/QDir>
#include <QtCore/QEvent>
#include <QtCore/QFileInfo>
#include <QtCore/QtDebug>

#include <chrono>
#include <filesystem>
#include <ranges>

namespace {
const auto kDefaultIdleTimeout = std::chrono::seconds(60);
const std::vector<std::filesystem::path> kPossibleConfigPaths{
    std::filesystem::path{std::filesystem::current_path() /
                          std::filesystem::path{"config"}},
    std::filesystem::path{SOURCE_DIRECTORY / std::filesystem::path{"config"}},
    std::filesystem::path{"/sdcard/Download/qt-hass/config"}};

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
}

void Controler::init() {
  const auto res =
      std::find_if(kPossibleConfigPaths.begin(), kPossibleConfigPaths.end(),
                   [](const std::filesystem::path &p) {
                     try {
                       return std::filesystem::exists(p) &&
                              std::filesystem::exists(p / "dashboards.yml");
                     } catch (const std::exception &) {
                       return false;
                     }
                   });

  if (res != kPossibleConfigPaths.end())
    loadConfig(std::filesystem::path{*res} / "dashboards.yml");
  else {
    loadConfig("bundle.yaml");
  }
}

bool Controler::eventFilter(QObject *obj, QEvent *event) {

  if (event->type() == QEvent::TouchBegin ||
      event->type() == QEvent::KeyPress ||
      event->type() == QEvent::MouseButtonPress ||
      event->type() == QEvent::MouseButtonDblClick ||
      event->type() == QEvent::MouseMove) {
    Q_EMIT idle(false);
    is_idle_timer_.start();
    has_user_interaction_ = true;
  }

  return false;
}

void Controler::loadConfig(const std::filesystem::path &path) {}

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
