#include "controller.h"

#include <QtCore/QDateTime>
#include <QtCore/QEvent>
#include <QtCore/QtDebug>

#include <chrono>
#include <iostream>
#include <ranges>

#include <yaml-cpp/yaml.h>

namespace {
const auto kDefaultIdleTimeout = std::chrono::seconds(15);
const std::vector<std::filesystem::path> kPossibleConfigPaths{
    std::filesystem::path{std::filesystem::current_path() /
                          std::filesystem::path{"config"}},
    std::filesystem::path{SOURCE_DIRECTORY / std::filesystem::path{"config"}},
    std::filesystem::path{"/sdcard/Download/qt-hass/config"}};

QVariant toVariant(YAML::Node node) {
  switch (node.Type()) {
  case YAML::NodeType::Undefined:
  case YAML::NodeType::Null:
  case YAML::NodeType::Scalar: {
    return QString::fromStdString(node.as<std::string>());
  }
  case YAML::NodeType::Sequence: {
    QVariantList list;
    for (const auto node_entry : node) {
      QVariant single_var = toVariant(node_entry);
      list.append(single_var);
    }
    return list;

    break;
  }
  case YAML::NodeType::Map: {
    QVariantMap map;
    for (YAML::const_iterator it = node.begin(); it != node.end(); ++it) {
      map[QString::fromStdString(it->first.as<std::string>())] =
          toVariant(it->second);
    }
    return map;
  } break;
  }

  return QVariant{};
}

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
  const auto res = std::ranges::find_if(
      kPossibleConfigPaths, [](const std::filesystem::path &p) {
        return std::filesystem::exists(p) &&
               std::filesystem::exists(p / "dashboards.yml");
      });

  if (res != kPossibleConfigPaths.end())
    loadConfig(std::filesystem::path{*res} / "dashboards.yml");
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

void Controler::loadConfig(const std::filesystem::path &path) {
  qDebug() << "Loading file " << path.string();
  YAML::Node config = YAML::LoadFile(path.string());

  if (config.IsNull()) {
    qWarning() << "Unable to load " << path.string();
    return;
  }

  const auto v = toVariant(config);
  Q_EMIT configurationChanged(v);

  configuration_file_watcher_.addPath(QString::fromStdString(path.string()));

  configuration_path_ = QString::fromStdString(path.string());
  Q_EMIT configurationPathChanged();
}
