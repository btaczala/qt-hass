#ifndef DASHBOARDSYNC_H
#define DASHBOARDSYNC_H

#include <QtCore/QDateTime>
#include <QtCore/QHash>
#include <QtCore/QObject>
#include <QtCore/QSet>
#include <QtCore/QStringList>
#include <QtCore/QUrl>
#include <QtQml/QQmlEngine>
#include <QtQml/QQmlError>

class QNetworkAccessManager;
class QNetworkReply;

// Downloads the user's dashboard -- a root QML file, an optional screensaver
// file next to it, plus the files the qmldir next to it lists -- into a local
// cache and says where to load them from.
//
// Every successful download goes into its own directory, named after a hash of
// the files, so a changed dashboard always gets new file URLs: the QML engine
// caches components by URL, and loading the same URL again would otherwise give
// the old code back. A failed download leaves the last good copy in place.
// A file:// dashboard URL is copied the same way, for developing a dashboard
// locally.
class DashboardSync : public QObject {
  Q_OBJECT
  QML_ELEMENT
  QML_SINGLETON

  Q_PROPERTY(bool syncing READ syncing NOTIFY syncingChanged)
  // The root QML file to load, in the cache. Empty while there's nothing to
  // load.
  Q_PROPERTY(QUrl localUrl READ localUrl NOTIFY localUrlChanged)
  // The screensaver QML file, in the same cached copy. Empty without one.
  Q_PROPERTY(QUrl screensaverUrl READ screensaverUrl NOTIFY localUrlChanged)
  // Why the last download failed; empty after a successful one.
  Q_PROPERTY(QString error READ error NOTIFY errorChanged)
  // When the files at localUrl were downloaded.
  Q_PROPERTY(QDateTime syncedAt READ syncedAt NOTIFY localUrlChanged)
  // The latest QML warnings from the dashboard's own files, oldest first, as
  // "File.qml:line: message".
  Q_PROPERTY(QStringList warnings READ warnings NOTIFY warningsChanged)

public:
  explicit DashboardSync(QQmlEngine *engine, QObject *parent = nullptr);

  static DashboardSync *create(QQmlEngine *engine, QJSEngine *) {
    return new DashboardSync(engine, engine);
  }

  bool syncing() const noexcept { return syncing_; }
  QUrl localUrl() const noexcept { return local_url_; }
  QUrl screensaverUrl() const noexcept { return screensaver_url_; }
  QString error() const noexcept { return error_; }
  QDateTime syncedAt() const noexcept { return synced_at_; }
  QStringList warnings() const noexcept { return warnings_; }

  // Downloads the dashboard at `url` (its root QML file) and, when given, the
  // `screensaver` QML file next to it, replacing any download still running.
  // synced() follows either way.
  Q_INVOKABLE void sync(const QString &url, const QString &screensaver = {});
  Q_INVOKABLE void clearWarnings();

signals:
  void syncingChanged();
  void localUrlChanged();
  void errorChanged();
  void warningsChanged();
  // A download finished: `ok` false when it failed (localUrl then still
  // points at the last good copy for this URL, if any).
  void synced(bool ok);

private:
  struct Download {
    // The dashboard URL as configured, and parsed.
    QString url;
    QUrl root;
    QString rootName;
    QString screensaverName;
    QSet<QString> requested;
    QHash<QString, QByteArray> files;
    int pending{0};
  };

  void fetch(const QString &name, bool optional);
  // Keeps a downloaded file; for the qmldir, returns the files it lists.
  // Fails the download (download_.root becomes invalid) on a bad qmldir.
  QStringList addFile(const QString &name, const QByteArray &data);
  void fileFinished(QNetworkReply *reply, const QString &name, bool optional);
  void finish();
  void fail(const QString &message);
  void setSyncing(bool syncing);
  void setError(const QString &error);
  void setLocal(const QUrl &url, const QUrl &screensaverUrl,
                const QDateTime &syncedAt);
  // Deletes cached copies other than `keep`.
  void prune(const QString &keep) const;
  void addWarnings(const QList<QQmlError> &warnings);
  QString cacheRoot() const;

  QNetworkAccessManager *network_;
  QList<QNetworkReply *> replies_;
  Download download_;
  bool syncing_{false};
  QUrl local_url_;
  QUrl screensaver_url_;
  QString error_;
  QDateTime synced_at_;
  QStringList warnings_;
};

#endif // DASHBOARDSYNC_H
