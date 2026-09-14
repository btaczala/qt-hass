#include "hassapi.h"
#include "controller.h"
#include <QLoggingCategory>
#include <QSslError>
#include <QTimer>
#include <QWebSocket>

#include <QJsonArray>
#include <QJsonObject>

#include <algorithm>

Q_DECLARE_LOGGING_CATEGORY(hassAPI)

Q_LOGGING_CATEGORY(hassAPI, "qthass.api")

using namespace std::chrono_literals;

namespace {
constexpr auto kRetryInterval = 5s;
constexpr auto kConnectTimeout = 20s;
constexpr auto kPingInterval = 30s;

QUrl defaultUrl() { return QUrl{Controler::create(nullptr, nullptr)->hassUrl()}; }
QString defaultAccessToken() {
  return Controler::create(nullptr, nullptr)->hassToken();
}
} // namespace

HassAPI::HassAPI(QObject *parent)
    : QObject(parent), socket_(new QWebSocket{}), url_(defaultUrl()),
      connected_(false), retry_timer_(new QTimer{this}),
      connect_timeout_(new QTimer{this}), ping_timer_(new QTimer{this}) {
  socket_->setParent(this);

  retry_timer_->setSingleShot(true);
  retry_timer_->setInterval(kRetryInterval);
  QObject::connect(retry_timer_, &QTimer::timeout, this, &HassAPI::connect);

  connect_timeout_->setSingleShot(true);
  connect_timeout_->setInterval(kConnectTimeout);
  QObject::connect(connect_timeout_, &QTimer::timeout, this, [this]() {
    dropConnection("connection attempt timed out");
  });

  ping_timer_->setInterval(kPingInterval);
  QObject::connect(ping_timer_, &QTimer::timeout, this, &HassAPI::sendPing);

  message_handlers_["auth_required"] = [this](QJsonDocument payload) {
    QJsonDocument resp_doc;
    QJsonObject resp_json;
    resp_json["type"] = QLatin1StringView{"auth"};
    resp_json["access_token"] = defaultAccessToken();
    resp_doc.setObject(resp_json);

    socket_->sendTextMessage(resp_doc.toJson());
  };

  message_handlers_["auth_ok"] = [this](QJsonDocument payload) {
    qCInfo(hassAPI) << "Connected to " << url_;
    connect_timeout_->stop();
    awaiting_pong_ = false;
    ping_timer_->start();
    connected_ = true;
    // QML components created in response to this may call
    // registerStateChanges(), which subscribes on its own now that
    // connected_ is set.
    emit connectedChanged();

    // Anything registered before we were connected still needs a
    // subscription.
    for (const QString &entity_id : state_changed_entity_handlers_.keys())
      subscribeToEntity(entity_id);
  };

  // HA closes the socket itself after this, which schedules a retry; the
  // token may just not be valid yet (e.g. still being set up), so keep trying.
  message_handlers_["auth_invalid"] = [this](QJsonDocument payload) {
    qCCritical(hassAPI) << "Authentication rejected by" << url_ << ":"
                        << payload["message"].toString();
    emit authenticationFailed(payload["message"].toString());
  };

  message_handlers_["pong"] = [this](QJsonDocument) { awaiting_pong_ = false; };

  message_handlers_["result"] = [this](QJsonDocument payload) {
    const bool success = payload["success"].toBool(true);
    if (!success)
      qCWarning(hassAPI) << "Request" << payload["id"].toInt()
                         << "failed:" << payload["error"]["message"].toString();

    const auto pending = pending_commands_.find(payload["id"].toInt());
    if (pending == pending_commands_.end())
      return;
    const PendingCommand command = pending.value();
    pending_commands_.erase(pending);
    if (!command.owner || !command.callback.isCallable())
      return;

    // QJsonDocument only holds an object or array, so wrap the result (which
    // can also be a plain value, e.g. auth/long_lived_access_token's string)
    // in an array and strip the brackets again.
    const QByteArray wrapped =
        QJsonDocument{QJsonArray{payload["result"]}}.toJson(QJsonDocument::Compact);
    const QString serialized = QString::fromUtf8(wrapped.sliced(1, wrapped.size() - 2));
    if (const QJSValue ret = QJSValue{command.callback}.call(
            {success, serialized, payload["error"]["message"].toString()});
        ret.isError())
      qCCritical(hassAPI) << "Command callback threw:" << ret.toString();
  };
  message_handlers_["event"] = [this](QJsonDocument payload) {
    eventHandler(payload);
  };

  QObject::connect(socket_, &QWebSocket::stateChanged,
                   [this](QAbstractSocket::SocketState state) {
                     qCDebug(hassAPI) << state;
                   });

  QObject::connect(socket_, &QWebSocket::disconnected, [this]() {
    resetSession();

    // closeCode() is only meaningful once a WebSocket connection actually
    // existed; on a failed connect it still reads as a clean 1000, which
    // makes a connect failure look like a normal shutdown.
    if (socket_established_) {
      socket_established_ = false;
      qCInfo(hassAPI) << "Disconnected from" << url_ << "- close code"
                      << socket_->closeCode() << "reason"
                      << socket_->closeReason();
    } else {
      qCCritical(hassAPI) << "Never connected to" << url_
                          << "- check that the host is reachable and the"
                             " scheme matches (wss for TLS, ws for plain)";
    }
    scheduleRetry();
  });

  QObject::connect(socket_, &QWebSocket::errorOccurred,
                   [this](QAbstractSocket::SocketError) {
                     qCCritical(hassAPI) << "Socket error on" << url_ << ":"
                                         << socket_->errorString();
                   });

  QObject::connect(
      socket_, &QWebSocket::sslErrors, [this](const QList<QSslError> &errors) {
        for (const auto &error : errors)
          qCCritical(hassAPI) << "SSL error:" << error.errorString();
      });

  QObject::connect(
      socket_, &QWebSocket::textMessageReceived, [this](QString message) {
        QJsonDocument json = QJsonDocument::fromJson(message.toUtf8());
        if (const auto obj = json["type"];
            !obj.isUndefined() && obj.isString()) {
          if (message_handlers_.contains(obj.toString())) {
            message_handlers_.value(obj.toString())(json);
          } else {
            qCWarning(hassAPI) << "No handler for " << obj.toString();
          }
        }
      });

  QObject::connect(socket_, &QWebSocket::connected, [this]() {
    socket_established_ = true;
    qCDebug(hassAPI) << "Connected to web socket";
  });
}

void HassAPI::connect() {
  keep_connected_ = true;
  retry_timer_->stop();
  if (socket_->state() != QAbstractSocket::UnconnectedState)
    return;
  // Re-read on every attempt, so a retry picks up settings changed meanwhile.
  url_ = defaultUrl();
  qCDebug(hassAPI) << "Connecting to " << url_;
  connect_timeout_->start();
  socket_->open(url_);
}

void HassAPI::reconnect() {
  socket_->abort();
  // abort() only emits disconnected() for a socket that had actually
  // connected, so don't rely on that handler to reset the session state.
  resetSession();
  connect();
}

void HassAPI::resetSession() {
  connect_timeout_->stop();
  ping_timer_->stop();
  awaiting_pong_ = false;
  subscribed_entities_.clear();
  entity_states_.clear();
  pending_commands_.clear();
  if (connected_) {
    connected_ = false;
    emit connectedChanged();
  }
}

void HassAPI::dropConnection(const char *reason) {
  qCWarning(hassAPI) << "Dropping connection to" << url_ << "-" << reason;
  socket_->abort();
  // As in reconnect(): disconnected() may or may not have run by now.
  resetSession();
  scheduleRetry();
}

void HassAPI::scheduleRetry() {
  if (!keep_connected_ || retry_timer_->isActive())
    return;
  qCInfo(hassAPI) << "Retrying in"
                  << std::chrono::duration_cast<std::chrono::seconds>(
                         kRetryInterval)
                         .count()
                  << "s";
  retry_timer_->start();
}

void HassAPI::sendPing() {
  if (awaiting_pong_) {
    dropConnection("no pong from the last ping");
    return;
  }
  awaiting_pong_ = true;
  QJsonObject request;
  request["id"] = request_id++;
  request["type"] = QLatin1StringView{"ping"};
  socket_->sendTextMessage(QJsonDocument{request}.toJson());
}

void HassAPI::registerStateChanges(QString entity_id, QJSValue fn) {
  if (!fn.isCallable()) {
    qCCritical(hassAPI) << " Callback must be a function";
    return;
  }

  qCDebug(hassAPI) << "Registering callback for" << entity_id;

  if (state_changed_entity_handlers_.contains(entity_id)) {
    auto &list = state_changed_entity_handlers_[entity_id];
    list << fn;
  } else {
    state_changed_entity_handlers_[entity_id] = QJSValueList{} << fn;
  }

  if (!connected_)
    return; // auth_ok subscribes for everything registered so far

  if (subscribed_entities_.contains(entity_id)) {
    // Already streaming this entity; replay the state we last saw so the
    // new callback isn't left blank until the next change. Queued, not
    // called straight away: registerStateChanges() is typically called from
    // a QML component's Component.onCompleted, and a batch of many at once
    // (e.g. a Repeater instantiating dozens of Tile{}) means this runs
    // while the QML engine is still mid-incubation of that batch. Calling
    // back into JS (invokeCallbacks ultimately does QJSValue::call) from
    // there re-enters the engine during object construction, which crashed
    // its GC on-device after enough accumulated objects.
    if (entity_states_.contains(entity_id))
      QMetaObject::invokeMethod(
          this, [this, entity_id, fn]() { invokeCallbacks(entity_id, {fn}); },
          Qt::QueuedConnection);
  } else {
    subscribeToEntity(entity_id);
  }
}

void HassAPI::unregisterStateChanges(QString entity_id, QJSValue fn) {
  const auto it = state_changed_entity_handlers_.find(entity_id);
  if (it == state_changed_entity_handlers_.end())
    return;

  qCDebug(hassAPI) << "Unregistering callback for" << entity_id;

  QJSValueList &callbacks = it.value();
  for (qsizetype i = callbacks.size() - 1; i >= 0; --i) {
    if (callbacks.at(i).strictlyEquals(fn))
      callbacks.removeAt(i);
  }

  if (callbacks.isEmpty())
    state_changed_entity_handlers_.erase(it);
}

void HassAPI::subscribeToEntity(const QString &entity_id) {
  if (subscribed_entities_.contains(entity_id))
    return;
  subscribed_entities_.insert(entity_id);

  // Deliberately *not* get_states: that returns every entity in the
  // instance (~2.5 MB here), which takes longer than QWebSocket's 5 s
  // incomplete-frame timeout to arrive over a remote connection and gets
  // the socket torn down with close code 1001. subscribe_entities with an
  // entity_ids filter sends only what we asked for, initial state included.
  QJsonDocument resp_doc;
  QJsonObject resp_json;
  resp_json["id"] = request_id++;
  resp_json["type"] = QLatin1StringView{"subscribe_entities"};
  resp_json["entity_ids"] = QJsonArray{entity_id};
  resp_doc.setObject(resp_json);

  socket_->sendTextMessage(resp_doc.toJson());
}

void HassAPI::eventHandler(QJsonDocument payload) {
  const auto event = payload["event"];

  // subscribe_entities uses HA's compressed state format:
  //   "a" - entities added to the subscription (full state)
  //   "c" - changed, as a "+"/"-" diff against what we already hold
  //   "r" - removed
  const auto added = event["a"].toObject();
  for (auto it = added.constBegin(); it != added.constEnd(); ++it) {
    const QJsonObject entity = it.value().toObject();
    QJsonObject state;
    state["entity_id"] = it.key();
    state["state"] = entity["s"];
    state["attributes"] = entity["a"];
    // Seconds since the epoch, as HA sends it.
    state["last_changed"] = entity["lc"];
    entity_states_[it.key()] = state;
    invokeCallbacks(it.key());
  }

  const auto changed = event["c"].toObject();
  for (auto it = changed.constBegin(); it != changed.constEnd(); ++it) {
    if (!entity_states_.contains(it.key()))
      continue;
    applyStateDiff(it.key(), it.value().toObject());
    invokeCallbacks(it.key());
  }

  for (const auto &removed : event["r"].toArray())
    entity_states_.remove(removed.toString());
}

void HassAPI::applyStateDiff(const QString &entity_id,
                             const QJsonObject &diff) {
  QJsonObject &state = entity_states_[entity_id];
  QJsonObject attributes = state["attributes"].toObject();

  const auto plus = diff["+"].toObject();
  if (plus.contains("s"))
    state["state"] = plus["s"];
  if (plus.contains("lc"))
    state["last_changed"] = plus["lc"];
  const auto added_attributes = plus["a"].toObject();
  for (auto it = added_attributes.constBegin();
       it != added_attributes.constEnd(); ++it)
    attributes[it.key()] = it.value();

  for (const auto &name : diff["-"].toObject()["a"].toArray())
    attributes.remove(name.toString());

  state["attributes"] = attributes;
}

void HassAPI::invokeCallbacks(const QString &entity_id,
                              const QJSValueList &callbacks) {
  const QJsonDocument doc{entity_states_.value(entity_id)};
  const QString serialized{doc.toJson()};

  const QJSValueList &targets =
      callbacks.isEmpty() ? state_changed_entity_handlers_.value(entity_id)
                          : callbacks;
  std::ranges::for_each(targets, [&](const QJSValue &callback) {
    QJSValueList args;
    args << serialized;
    // QJSValue::call() reports a thrown JS exception through its return
    // value; without this the QML callback can fail silently.
    if (const QJSValue result = callback.call(args); result.isError())
      qCCritical(hassAPI) << "Callback for" << entity_id << "threw:"
                          << result.property("fileName").toString() + ":" +
                                 result.property("lineNumber").toString()
                          << result.toString();
  });
}

void HassAPI::callService(const QString &domain, const QString &service,
                          const QString &entity_id,
                          const QVariantMap &service_data) {
  QJsonObject request;
  request["id"] = request_id++;
  request["type"] = QLatin1StringView{"call_service"};
  request["domain"] = domain;
  request["service"] = service;
  request["target"] = QJsonObject{{"entity_id", entity_id}};
  if (!service_data.isEmpty())
    request["service_data"] = QJsonObject::fromVariantMap(service_data);

  socket_->sendTextMessage(QJsonDocument{request}.toJson());
}

bool HassAPI::command(const QString &type, const QVariantMap &params,
                      QObject *owner, QJSValue callback) {
  if (!connected_) {
    qCWarning(hassAPI) << "Not connected, dropping command" << type;
    return false;
  }
  QJsonObject request = QJsonObject::fromVariantMap(params);
  const int id = request_id++;
  request["id"] = id;
  request["type"] = type;
  pending_commands_.insert(id, {owner, callback});
  socket_->sendTextMessage(QJsonDocument{request}.toJson(QJsonDocument::Compact));
  return true;
}

void HassAPI::light(QString entity_id, bool on) {
  callService("light", on ? "turn_on" : "turn_off", entity_id);
}
