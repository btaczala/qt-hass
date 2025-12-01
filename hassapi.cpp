#include "hassapi.h"
#include <QFile>
#include <QLoggingCategory>
#include <QTimer>
#include <QWebSocket>

#include <QJsonArray>
#include <QJsonObject>

#include <algorithm>
#include <ranges>

Q_DECLARE_LOGGING_CATEGORY(hassAPI)

Q_LOGGING_CATEGORY(hassAPI, "qthass.api")

namespace {
const auto default_url = "ws://192.168.1.40:8123/api/websocket";
const auto access_token =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    "eyJpc3MiOiI1MmZjMThmYWU3YTc0NzhiOGY5ZDFjNDM0OGI0YmI1NCIsImlhdCI6MTcyNzgxMD"
    "MyMCwiZXhwIjoyMDQzMTcwMzIwfQ.Trt5hwKRUI3XqLJeKs4-Dm1QEpNlip7qfLJmBOB0MoY";
} // namespace

HassAPI::HassAPI(QObject *parent)
    : QObject(parent), socket_(new QWebSocket{}), url_(default_url),
      subscription_id_(std::rand() % 100), connected_(false) {
  socket_->setParent(this);

  message_handlers_["auth_required"] = [this](QJsonDocument payload) {
    QJsonDocument resp_doc;
    QJsonObject resp_json;
    resp_json["type"] = QLatin1StringView{"auth"};
    resp_json["access_token"] = QLatin1StringView{access_token};
    resp_doc.setObject(resp_json);

    socket_->sendTextMessage(resp_doc.toJson());
  };

  message_handlers_["auth_ok"] = [this](QJsonDocument payload) {
    QTimer::singleShot(std::chrono::seconds(1), this, &HassAPI::refreshStates);
  };

  message_handlers_["result"] =
      std::bind(&HassAPI::handler_result, this, std::placeholders::_1);
  message_handlers_["event"] = [this](QJsonDocument payload) {
    qCCritical(hassAPI) << "Not implemented" << payload;
  };

  QObject::connect(socket_, &QWebSocket::stateChanged,
                   [this](QAbstractSocket::SocketState state) {
                     qCDebug(hassAPI) << state;
                   });

  QObject::connect(
      socket_, &QWebSocket::textMessageReceived, [this](QString message) {
        QJsonDocument json = QJsonDocument::fromJson(message.toLocal8Bit());
        if (const auto obj = json["type"];
            !obj.isUndefined() && obj.isString()) {
          if (message_handlers_.contains(obj.toString())) {
            message_handlers_.value(obj.toString())(json);
          } else {
            qCWarning(hassAPI) << "No handler for " << obj.toString();
          }
        }
      });

  QObject::connect(socket_, &QWebSocket::connected,
                   []() { qCDebug(hassAPI()) << "Connected"; });
}

void HassAPI::connect() { socket_->open(url_); }

void HassAPI::registerStateChanges(QString entity_id, QJSValue fn) {
  if (!fn.isCallable()) {
    qCCritical(hassAPI) << " Callback must be a function";
  }

  qCInfo(hassAPI) << "Registering callback for" << entity_id;

  if (state_changed_entity_handlers_.contains(entity_id)) {
    auto &list = state_changed_entity_handlers_[entity_id];
    list << fn;
  } else {
    state_changed_entity_handlers_[entity_id] = QJSValueList{} << fn;
  }
}

void HassAPI::subscribe() {
  QJsonDocument resp_doc;
  QJsonObject resp_json;
  resp_json["id"] = subscription_id_;
  resp_json["type"] = QLatin1StringView{"subscribe_events"};
  resp_json["event_type"] = QLatin1StringView{"state_changed"};
  resp_doc.setObject(resp_json);

  socket_->sendTextMessage(resp_doc.toJson());
}

void HassAPI::refreshStates() {
  get_states_id = std::rand() % 1000;
  qCDebug(hassAPI) << "Getting all states";
  QJsonDocument resp_doc;
  QJsonObject resp_json;
  resp_json["id"] = get_states_id;
  resp_json["type"] = QLatin1StringView{"get_states"};
  resp_doc.setObject(resp_json);

  socket_->sendTextMessage(resp_doc.toJson());
}

void HassAPI::handler_result(QJsonDocument payload) {
  if (true) {
    QFile file{QString{"result_%1.json"}.arg(payload["id"].toInt())};
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
      qCInfo(hassAPI) << "Writing file " << file.fileName();
      file.write(payload.toJson());
    }
    file.close();
  }

  if (payload["id"].toInt() == get_states_id) {
    {
      qCInfo(hassAPI) << "Connected to " << url_;
      connected_ = true;
      emit connectedChanged();
    }
    const auto &results = payload["result"].toArray();

    auto filtered = results | std::views::filter([this](const QJsonValue &val) {
                      return std::ranges::any_of(
                          state_changed_entity_handlers_.keys(),
                          [&val](const QString &key) {
                            return key == val["entity_id"].toString();
                          });
                    });
    for (QJsonValue v : filtered) {
      const QJSValueList &callbacks =
          state_changed_entity_handlers_.value(v["entity_id"].toString());
      std::ranges::for_each(callbacks, [&v](const QJSValue &callback) {
        QJSValueList list;
        QJsonDocument doc{v.toObject()};
        list << QString{doc.toJson()};
        callback.call(list);
      });
      ;
    }
  }
}
