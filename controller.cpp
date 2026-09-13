#include "controller.h"

#include <QtCore/QEvent>
#include <QtCore/QFile>
#include <QtCore/QSettings>
#include <QtCore/QtDebug>

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
} // namespace

Controler::Controler(QObject *parent)
    : QObject(parent), has_user_interaction_(false) {

  const QSettings settings;
  is_idle_timer_.setInterval(
      std::chrono::seconds(settings
                               .value(kIdleTimeoutKey,
                                      qint64(kDefaultIdleTimeout.count()))
                               .toInt()));
  connect(&is_idle_timer_, &QTimer::timeout, this, [this]() {
    qDebug() << "idle";
    Q_EMIT idle(true);
  });

  is_idle_timer_.start();
  is_idle_timer_.setSingleShot(true);

  loadConnection();
}

void Controler::loadConnection() {
  const QString old_url = hass_url_;
  const QString old_token = hass_token_;
  hass_url_.clear();
  hass_token_.clear();

  loadConfig();

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

int Controler::idleTimeout() const {
  return std::chrono::duration_cast<std::chrono::seconds>(
             is_idle_timer_.intervalAsDuration())
      .count();
}

void Controler::setIdleTimeout(int seconds) {
  if (seconds <= 0 || seconds == idleTimeout())
    return;
  // setInterval() restarts an active timer, which is what we want: the new
  // timeout counts from now.
  is_idle_timer_.setInterval(std::chrono::seconds(seconds));
  QSettings{}.setValue(kIdleTimeoutKey, seconds);
  Q_EMIT idleTimeoutChanged();
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

    const QByteArray key = line.first(separator).trimmed();
    const QByteArray value = line.sliced(separator + 1).trimmed();
    if (key == "HASS_URL")
      hass_url_ = QString::fromUtf8(value);
    else if (key == "HASS_TOKEN")
      hass_token_ = QString::fromUtf8(value);
  }
}
