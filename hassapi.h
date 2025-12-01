#ifndef HASSAPI_H
#define HASSAPI_H

#include <QQmlEngine>
#include <QtCore/QJsonDocument>
#include <QtCore/QObject>

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
  void registerStateChanges(QString, QJSValue);

  void refreshStates();

signals:
  void error(QString);
  void connectedChanged();

private slots:
  void subscribe();

private:
  void handler_result(QJsonDocument);

  QWebSocket *socket_;
  QUrl url_;
  int subscription_id_;
  int get_states_id;
  bool connected_;

  QMap<QString, std::function<void(QJsonDocument)>> message_handlers_;
  QMap<QString, QJSValueList> state_changed_entity_handlers_;
};

#endif // HASSAPI_H
