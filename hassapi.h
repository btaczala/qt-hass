#ifndef HASSAPI_H
#define HASSAPI_H

#include <QQmlEngine>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <QtCore/QObject>
#include <QtCore/QSet>
#include <QtCore/QVariantMap>

#include <functional>

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
  void connect();
  // Drops the current connection, if any, and connects again with the URL and
  // token currently set on Controler.
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

signals:
  void error(QString);
  void connectedChanged();

private:
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
  // Whether the WebSocket handshake ever completed on this connection.
  bool socket_established_{false};

  QMap<QString, std::function<void(QJsonDocument)>> message_handlers_;
  QMap<QString, QJSValueList> state_changed_entity_handlers_;
  // Latest full state per entity, rebuilt from HA's compressed diffs.
  QMap<QString, QJsonObject> entity_states_;
  QSet<QString> subscribed_entities_;
  int request_id{1};
};

#endif // HASSAPI_H
