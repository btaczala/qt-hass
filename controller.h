#ifndef CONTROLLER
#define CONTROLLER

#include <QtCore/QObject>
#include <QtCore/QTimer>
#include <QtCore/QVariant>
#include <QtQml/qqmlregistration.h>

class QQmlEngine;
class QJSEngine;

class Controler : public QObject {
  Q_OBJECT
  QML_ELEMENT
  QML_SINGLETON
  Q_PROPERTY(QString hassUrl READ hassUrl WRITE setHassUrl NOTIFY
                 hassUrlChanged)
  Q_PROPERTY(QString hassToken READ hassToken WRITE setHassToken NOTIFY
                 hassTokenChanged)
  // Seconds without user input before idle(true) is emitted.
  Q_PROPERTY(int idleTimeout READ idleTimeout WRITE setIdleTimeout NOTIFY
                 idleTimeoutChanged)

public:
  static Controler *create(QQmlEngine *, QJSEngine *) {
    if (!s_instance)
      s_instance = new Controler();
    return s_instance;
  }
  static Controler *instance() { return s_instance; }

  Controler(QObject *parent = nullptr);

  // HASS_URL/HASS_TOKEN, resolved in increasing priority from the bundled
  // :/qt-hass/config resource (generated from .envrc at configure time), the
  // process environment, and values saved from the settings page. Setting
  // them saves them; HassAPI::reconnect() picks them up.
  QString hassUrl() const noexcept { return hass_url_; }
  QString hassToken() const noexcept { return hass_token_; }
  void setHassUrl(const QString &url);
  void setHassToken(const QString &token);
  // Forgets URL/token saved from the settings page, falling back to the
  // environment and bundled config again.
  Q_INVOKABLE void clearSavedConnection();

  int idleTimeout() const;
  void setIdleTimeout(int seconds);

protected:
  bool eventFilter(QObject *obj, QEvent *event) override;

signals:

  void hassUrlChanged();
  void hassTokenChanged();
  void idleTimeoutChanged();

  void idle(bool);
  void requestDetails(QString entity_id, QString friendly_name);
  void configurationChanged(QVariant configuration);

  void error(QString);

  // HassAPI
  //
  void hassApiRequestDataUpdated(QString entity_id, QVariant data);

private:
  void loadConfig();
  void loadConnection();

  static Controler *s_instance;

  bool has_user_interaction_;
  QTimer is_idle_timer_;
  QString hass_url_;
  QString hass_token_;
};

#endif // !CONTROLLER
