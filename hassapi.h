#ifndef HASSAPI_H
#define HASSAPI_H

#include <QQmlEngine>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <QtCore/QObject>
#include <QtCore/QPointer>
#include <QtCore/QSet>
#include <QtCore/QVariantMap>

#include <functional>

class QTimer;
class QWebSocket;

class HassAPI : public QObject {
  Q_OBJECT
  QML_SINGLETON
  QML_NAMED_ELEMENT(HassAPI)

  Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged);

public:
  explicit HassAPI(QObject *parent = nullptr);

  static HassAPI *create(QQmlEngine *qmlEngine, QJSEngine *) {
    return new HassAPI(qmlEngine);
  }

  bool connected() const noexcept { return connected_; }

public slots:
  // Connects with the URL and token currently set on Controler, and keeps
  // the connection up from then on: a dropped or failed connection (e.g. HA
  // restarting) is retried every kRetryInterval.
  void connect();
  // Drops the current connection, if any, and connects again straight away.
  void reconnect();
  void registerStateChanges(QString, QJSValue);
  // Must be called with the exact same (entity_id, fn) pair passed to
  // registerStateChanges before the QML object owning fn is destroyed --
  // otherwise the stale closure stays in state_changed_entity_handlers_ and
  // the next state update for that entity calls into a deleted object.
  void unregisterStateChanges(QString, QJSValue);

  // Calls `domain.service` targeting `entity_id`, e.g.
  // callService("light", "turn_on", "light.desk", {{"brightness_pct", 40}}).
  void callService(const QString &domain, const QString &service,
                   const QString &entity_id,
                   const QVariantMap &service_data = {});
  void light(QString entity_id, bool on);

  // Sends a one-off WebSocket API command, e.g.
  // command("recorder/statistics_during_period", {...}, this, fn), and calls
  // fn(ok, resultJson, errorMessage) with the reply's `result` as a JSON
  // string, and HA's error message when it failed. The reply
  // is dropped if `owner` is destroyed first or the connection goes down
  // before it arrives, so pass the calling QML object as `owner`. Returns
  // false (and never calls back) when not connected.
  bool command(const QString &type, const QVariantMap &params, QObject *owner,
               QJSValue callback);

  // Sends a subscription command, e.g.
  // subscribe("persistent_notification/subscribe", {}, this, fn), and calls
  // fn(ok, eventJson, errorMessage) with each event's `event` as a JSON
  // string -- or once with ok false when HA refuses it (e.g. an admin-only
  // command for a non-admin user). Subscriptions end with the connection, so
  // subscribe again once `connected` is back. Ends early, unsubscribing, once
  // `owner` is destroyed. Returns the subscription id, or 0 (and never calls
  // back) when not connected.
  int subscribe(const QString &type, const QVariantMap &params, QObject *owner,
                QJSValue callback);
  void unsubscribe(int subscription);

signals:
  void error(QString);
  void connectedChanged();
  // HA rejected the token (auth_invalid); retries continue regardless.
  void authenticationFailed(QString message);

private:
  // Forgets everything tied to the current connection, emitting
  // connectedChanged() if it was up.
  void resetSession();
  // Abandons the connection (open, opening or silently dead) and schedules a
  // retry.
  void dropConnection(const char *reason);
  void scheduleRetry();
  void sendPing();
  void subscribeToEntity(const QString &entity_id);
  void eventHandler(QJsonDocument);
  void applyStateDiff(const QString &entity_id, const QJsonObject &diff);
  // Calls `callbacks` with the current state of `entity_id`, or every
  // callback registered for it when `callbacks` is empty.
  void invokeCallbacks(const QString &entity_id,
                       const QJSValueList &callbacks = {});

  QWebSocket *socket_;
  QUrl url_;
  bool connected_;
  // Set by connect(); until then nothing is retried.
  bool keep_connected_{false};
  QTimer *retry_timer_;
  // Gives up on a connection attempt that hasn't authenticated in time -- a
  // TCP connect to a host that's down can otherwise hang for over a minute.
  QTimer *connect_timeout_;
  // Pings HA every kPingInterval while connected; a ping still unanswered at
  // the next one means the connection is dead even though no close ever
  // arrived (host rebooted, network gone).
  QTimer *ping_timer_;
  bool awaiting_pong_{false};
  // Whether the WebSocket handshake ever completed on this connection.
  bool socket_established_{false};

  QMap<QString, std::function<void(QJsonDocument)>> message_handlers_;
  QMap<QString, QJSValueList> state_changed_entity_handlers_;
  // Latest full state per entity, rebuilt from HA's compressed diffs.
  QMap<QString, QJsonObject> entity_states_;
  QSet<QString> subscribed_entities_;
  struct PendingCommand {
    QPointer<QObject> owner;
    QJSValue callback;
  };
  QHash<int, PendingCommand> pending_commands_;
  // Live subscribe() callbacks by subscription id; unlike pending_commands_,
  // kept past the first result.
  QHash<int, PendingCommand> subscriptions_;
  int request_id{1};
};

#endif // HASSAPI_H
