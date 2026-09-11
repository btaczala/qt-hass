#ifndef CONTROLLER
#define CONTROLLER

#include <QtCore/QFileSystemWatcher>
#include <QtCore/QObject>
#include <QtCore/QTimer>
#include <QtCore/QVariant>
#include <QtCore/QUrl>
#include <QtQml/qqmlregistration.h>

#include <filesystem>

class QQmlEngine;
class QJSEngine;

class Controler : public QObject {
  Q_OBJECT
  QML_ELEMENT
  QML_SINGLETON
  Q_PROPERTY(QString configurationPath READ configurationPath NOTIFY
                 configurationPathChanged);

public:
  static Controler *create(QQmlEngine *, QJSEngine *) {
    if (!s_instance)
      s_instance = new Controler();
    return s_instance;
  }
  static Controler *instance() { return s_instance; }

  Controler(QObject *parent = nullptr);

  QString configurationPath() const noexcept { return configuration_path_; }

  // Fallback for HASS_URL/HASS_TOKEN on platforms with no process
  // environment to inherit them from (Android). Populated from the first
  // config file found among the paths loadConfig() searches, in KEY=VALUE
  // form.
  QString hassUrl() const noexcept { return hass_url_; }
  QString hassToken() const noexcept { return hass_token_; }

  Q_INVOKABLE QUrl pathFor(const QString& file);

protected:
  bool eventFilter(QObject *obj, QEvent *event) override;

signals:

  void configurationPathChanged();

  void idle(bool);
  void requestDetails(QString entity_id, QString friendly_name);
  void configurationChanged(QVariant configuration);

  void error(QString);

  // HassAPI
  //
  void hassApiRequestDataUpdated(QString entity_id, QVariant data);

private:
  // Returns false (after logging a warning) if `path` couldn't be opened.
  bool loadConfig(const std::filesystem::path &path);

  static Controler *s_instance;

  bool has_user_interaction_;
  QTimer is_idle_timer_;
  QFileSystemWatcher configuration_file_watcher_;
  QString configuration_path_;
  QString hass_url_;
  QString hass_token_;
};

#endif // !CONTROLLER
