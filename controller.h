#ifndef CONTROLLER
#define CONTROLLER

#include <QtCore/QFileSystemWatcher>
#include <QtCore/QObject>
#include <QtCore/QTimer>
#include <QtCore/QVariant>
#include <QtCore/QUrl>

#include <filesystem>

class Controler : public QObject {
  Q_OBJECT
  Q_PROPERTY(QString configurationPath READ configurationPath NOTIFY
                 configurationPathChanged);

public:
  Controler(QObject *parent = nullptr);

  void init();

  QString configurationPath() const noexcept { return configuration_path_; }

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
  void loadConfig(const std::filesystem::path &path);

  bool has_user_interaction_;
  QTimer is_idle_timer_;
  QFileSystemWatcher configuration_file_watcher_;
  QString configuration_path_;
};

#endif // !CONTROLLER
