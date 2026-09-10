#ifndef HASSAPI_H
#define HASSAPI_H

#include <QQmlEngine>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <QtCore/QObject>
#include <QtCore/QSet>

#include <functional>
#include <mutex>

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
  void registerStateChanges(QString, QJSValue);

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
  std::mutex requestMutex_;
  QMap<int, QString> requests_;
  int request_id{1};
};

#endif // HASSAPI_H
