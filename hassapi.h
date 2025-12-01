#ifndef HASSAPI_H
#define HASSAPI_H

#include <QQmlEngine>
#include <QtCore/QJsonDocument>
#include <QtCore/QObject>

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
  void refreshStates();

  void light(QString entity_id, bool on);

signals:
  void error(QString);
  void connectedChanged();

private slots:
  void subscribeForStateChanges();

private:
  void resultHandler(QJsonDocument);
  void eventHandler(QJsonDocument);

  QWebSocket *socket_;
  QUrl url_;
  bool connected_;

  std::atomic_int get_states_id_{0};

  QMap<QString, std::function<void(QJsonDocument)>> message_handlers_;
  QMap<QString, QJSValueList> state_changed_entity_handlers_;
  std::mutex requestMutex_;
  QMap<int, QString> requests_;
  int request_id{1};
};

#endif // HASSAPI_H
