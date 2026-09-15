#include "dashboardsync.h"

#include "controller.h"

#include <QtCore/QCryptographicHash>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QLoggingCategory>
#include <QtCore/QSaveFile>
#include <QtCore/QSettings>
#include <QtCore/QStandardPaths>
#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkReply>
#include <QtNetwork/QNetworkRequest>
#include <QtQml/QQmlEngine>
#include <QtQml/QQmlError>

#include <algorithm>
#include <chrono>

Q_LOGGING_CATEGORY(dashboardSync, "qthass.dashboard")

namespace {
const auto kTimeout = std::chrono::seconds(20);
// How many warnings `warnings` keeps.
const auto kMaxWarnings = 20;

// Which download the cache holds, so a changed dashboard URL doesn't show
// another URL's dashboard.
const auto kCachedUrlKey = QStringLiteral("dashboard/cachedUrl");
const auto kCachedDirKey = QStringLiteral("dashboard/cachedDir");
const auto kCachedRootKey = QStringLiteral("dashboard/cachedRoot");
const auto kCachedScreensaverKey = QStringLiteral("dashboard/cachedScreensaver");
const auto kSyncedAtKey = QStringLiteral("dashboard/syncedAt");

// qmldir lines that don't name a file of the dashboard.
const QStringList kQmldirKeywords = {
    QStringLiteral("module"),     QStringLiteral("plugin"),
    QStringLiteral("optional"),   QStringLiteral("classname"),
    QStringLiteral("typeinfo"),   QStringLiteral("depends"),
    QStringLiteral("import"),     QStringLiteral("designersupported"),
    QStringLiteral("static"),     QStringLiteral("system"),
    QStringLiteral("prefer"),     QStringLiteral("linktarget"),
    QStringLiteral("default")};

// The QML and JS files a qmldir lists, e.g. "MyCard 1.0 MyCard.qml",
// "singleton Theme 1.0 Theme.qml" or "Helpers 1.0 helpers.js".
QStringList qmldirFiles(const QByteArray &qmldir) {
  QStringList files;
  for (const QByteArray &rawLine : qmldir.split('\n')) {
    QStringList tokens =
        QString::fromUtf8(rawLine).simplified().split(u' ', Qt::SkipEmptyParts);
    if (tokens.isEmpty() || tokens.first().startsWith(u'#') ||
        kQmldirKeywords.contains(tokens.first()))
      continue;
    const QString file = tokens.last();
    if (file.endsWith(u".qml") || file.endsWith(u".js") ||
        file.endsWith(u".mjs"))
      files.append(file);
  }
  return files;
}

// Only plain relative paths below the dashboard's directory are downloaded.
bool isSafeRelativePath(const QString &path) {
  return !path.isEmpty() && !path.startsWith(u'/') && !path.contains(u'\\') &&
         !path.contains(u':') && !path.split(u'/').contains(u"..");
}

int defaultPort(const QString &scheme) {
  return scheme == u"https" || scheme == u"wss" ? 443 : 80;
}

// The Home Assistant token only goes to Home Assistant itself.
bool isHassHost(const QUrl &url) {
  const QUrl hass(Controler::instance()->hassUrl());
  return !hass.host().isEmpty() &&
         url.host().compare(hass.host(), Qt::CaseInsensitive) == 0 &&
         url.port(defaultPort(url.scheme())) ==
             hass.port(defaultPort(hass.scheme()));
}
} // namespace

DashboardSync::DashboardSync(QQmlEngine *engine, QObject *parent)
    : QObject(parent), network_(new QNetworkAccessManager(this)) {
  // The last good copy, if it's of the dashboard currently configured, so
  // it's there to load before (or without) a download.
  const QSettings settings;
  const QString dir = settings.value(kCachedDirKey).toString();
  const QString root = settings.value(kCachedRootKey).toString();
  const QString path = cacheRoot() + u'/' + dir + u'/' + root;
  if (!dir.isEmpty() &&
      settings.value(kCachedUrlKey).toString() ==
          Controler::instance()->dashboardUrl() &&
      QFile::exists(path)) {
    local_url_ = QUrl::fromLocalFile(path);
    synced_at_ = settings.value(kSyncedAtKey).toDateTime();
    // The screensaver only when it's the one configured, too.
    const QString screensaver =
        settings.value(kCachedScreensaverKey).toString();
    const QString screensaverPath = cacheRoot() + u'/' + dir + u'/' + screensaver;
    if (!screensaver.isEmpty() &&
        screensaver == Controler::instance()->screensaverFile() &&
        QFile::exists(screensaverPath))
      screensaver_url_ = QUrl::fromLocalFile(screensaverPath);
  }
  prune(dir);

  if (engine)
    connect(engine, &QQmlEngine::warnings, this, &DashboardSync::addWarnings);
}

QString DashboardSync::cacheRoot() const {
  return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) +
         u"/dashboard";
}

void DashboardSync::sync(const QString &url, const QString &screensaver) {
  qCDebug(dashboardSync) << "Sync requested for" << url << screensaver;
  for (QNetworkReply *reply : std::as_const(replies_)) {
    reply->disconnect(this);
    reply->abort();
    reply->deleteLater();
  }
  replies_.clear();
  download_ = {};

  const QUrl root = QUrl::fromUserInput(url.trimmed());
  if (url.trimmed().isEmpty()) {
    setLocal({}, {}, {});
    setError({});
    setSyncing(false);
    Q_EMIT synced(false);
    return;
  }
  // A copy of another URL's dashboard isn't this one's last good copy.
  if (QSettings{}.value(kCachedUrlKey).toString() != url)
    setLocal({}, {}, {});
  // Nor is another screensaver's this one's.
  else if (QSettings{}.value(kCachedScreensaverKey).toString() != screensaver)
    setLocal(local_url_, {}, synced_at_);

  if (!root.isValid() ||
      (root.scheme() != u"http" && root.scheme() != u"https" &&
       !root.isLocalFile()) ||
      !root.fileName().endsWith(u".qml")) {
    fail(tr("The dashboard URL has to be an http(s) or file URL of a .qml "
            "file: %1")
             .arg(url));
    return;
  }

  if (!screensaver.isEmpty() &&
      (!isSafeRelativePath(screensaver) || !screensaver.endsWith(u".qml"))) {
    fail(tr("The screensaver has to be a .qml file in the dashboard's "
            "directory: %1")
             .arg(screensaver));
    return;
  }

  qCInfo(dashboardSync) << "Downloading" << root;
  setSyncing(true);
  download_.root = root;
  download_.rootName = root.fileName();
  download_.screensaverName = screensaver;
  download_.url = url;

  // A dashboard on this machine, e.g. while writing one: copied like a
  // downloaded one, so each change still gets new file URLs.
  if (root.isLocalFile()) {
    QStringList queue = {download_.rootName, QStringLiteral("qmldir")};
    if (!screensaver.isEmpty())
      queue.append(screensaver);
    while (!queue.isEmpty()) {
      const QString name = queue.takeFirst();
      if (download_.files.contains(name))
        continue;
      QFile file(root.resolved(QUrl(name)).toLocalFile());
      if (!file.open(QIODevice::ReadOnly)) {
        if (name == u"qmldir")
          continue;
        fail(tr("Couldn't read %1: %2").arg(file.fileName(), file.errorString()));
        return;
      }
      const QStringList more = addFile(name, file.readAll());
      if (!download_.root.isValid())
        return; // addFile() failed
      queue.append(more);
    }
    finish();
    return;
  }

  fetch(download_.rootName, false);
  fetch(QStringLiteral("qmldir"), true);
  if (!screensaver.isEmpty())
    fetch(screensaver, false);
}

QStringList DashboardSync::addFile(const QString &name, const QByteArray &data) {
  download_.files.insert(name, data);
  if (name != u"qmldir")
    return {};
  const QStringList files = qmldirFiles(data);
  for (const QString &file : files) {
    if (!isSafeRelativePath(file)) {
      fail(tr("qmldir lists a file outside the dashboard's directory: %1")
               .arg(file));
      return {};
    }
  }
  return files;
}

void DashboardSync::fetch(const QString &name, bool optional) {
  if (download_.requested.contains(name))
    return;
  download_.requested.insert(name);

  QNetworkRequest request(download_.root.resolved(QUrl(name)));
  request.setTransferTimeout(kTimeout);
  if (isHassHost(request.url()))
    request.setRawHeader("Authorization",
                         "Bearer " + Controler::instance()->hassToken().toUtf8());

  QNetworkReply *reply = network_->get(request);
  replies_.append(reply);
  ++download_.pending;
  connect(reply, &QNetworkReply::finished, this, [this, reply, name, optional] {
    fileFinished(reply, name, optional);
  });
}

void DashboardSync::fileFinished(QNetworkReply *reply, const QString &name,
                                 bool optional) {
  replies_.removeOne(reply);
  reply->deleteLater();
  --download_.pending;

  const int status =
      reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
  if (reply->error() != QNetworkReply::NoError) {
    // No qmldir: a dashboard in a single file.
    if (!(optional && status == 404)) {
      fail(tr("Couldn't download %1: %2")
               .arg(reply->url().toString(), reply->errorString()));
      return;
    }
  } else {
    const QStringList more = addFile(name, reply->readAll());
    if (!download_.root.isValid())
      return; // addFile() failed
    for (const QString &file : more)
      fetch(file, false);
  }

  if (download_.pending == 0)
    finish();
}

void DashboardSync::finish() {
  // Named after the content, so the same dashboard lands in the same place
  // and a changed one in a new one.
  QStringList names = download_.files.keys();
  std::sort(names.begin(), names.end());
  QCryptographicHash hash(QCryptographicHash::Sha1);
  hash.addData(download_.rootName.toUtf8());
  for (const QString &name : std::as_const(names)) {
    hash.addData(name.toUtf8());
    hash.addData(QByteArrayView("\0", 1));
    hash.addData(download_.files.value(name));
    hash.addData(QByteArrayView("\0", 1));
  }
  const QString dirName = QString::fromLatin1(hash.result().toHex().left(20));
  const QString dir = cacheRoot() + u'/' + dirName;

  if (!QFile::exists(dir + u'/' + download_.rootName)) {
    const QString staging = cacheRoot() + u"/.staging";
    QDir(staging).removeRecursively();
    for (const QString &name : std::as_const(names)) {
      const QString path = staging + u'/' + name;
      QDir().mkpath(QFileInfo(path).absolutePath());
      QSaveFile file(path);
      if (!file.open(QIODevice::WriteOnly) ||
          file.write(download_.files.value(name)) < 0 || !file.commit()) {
        fail(tr("Couldn't save %1: %2").arg(path, file.errorString()));
        return;
      }
    }
    QDir(dir).removeRecursively();
    if (!QDir().rename(staging, dir)) {
      fail(tr("Couldn't save the dashboard to %1").arg(dir));
      return;
    }
  }

  const QString previous = QSettings{}.value(kCachedDirKey).toString();
  const QDateTime now = QDateTime::currentDateTime();
  QSettings settings;
  settings.setValue(kCachedUrlKey, download_.url);
  settings.setValue(kCachedDirKey, dirName);
  settings.setValue(kCachedRootKey, download_.rootName);
  settings.setValue(kCachedScreensaverKey, download_.screensaverName);
  settings.setValue(kSyncedAtKey, now);
  // The previous copy may still be loaded until the app switches over; it
  // goes on the next start.
  for (const QString &old :
       QDir(cacheRoot()).entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
    if (old != dirName && old != previous)
      QDir(cacheRoot() + u'/' + old).removeRecursively();
  }

  qCInfo(dashboardSync) << "Downloaded" << names.size() << "files to" << dir;
  setLocal(QUrl::fromLocalFile(dir + u'/' + download_.rootName),
           download_.screensaverName.isEmpty()
               ? QUrl()
               : QUrl::fromLocalFile(dir + u'/' + download_.screensaverName),
           now);
  setError({});
  setSyncing(false);
  Q_EMIT synced(true);
}

void DashboardSync::fail(const QString &message) {
  qCWarning(dashboardSync) << message;
  for (QNetworkReply *reply : std::as_const(replies_)) {
    reply->disconnect(this);
    reply->abort();
    reply->deleteLater();
  }
  replies_.clear();
  download_ = {};
  setError(message);
  setSyncing(false);
  Q_EMIT synced(false);
}

void DashboardSync::prune(const QString &keep) const {
  for (const QString &old :
       QDir(cacheRoot()).entryList(QDir::Dirs | QDir::NoDotAndDotDot |
                                   QDir::Hidden)) {
    if (old != keep)
      QDir(cacheRoot() + u'/' + old).removeRecursively();
  }
}

void DashboardSync::clearWarnings() {
  if (warnings_.isEmpty())
    return;
  warnings_.clear();
  Q_EMIT warningsChanged();
}

void DashboardSync::addWarnings(const QList<QQmlError> &warnings) {
  const QString dir =
      local_url_.isValid()
          ? local_url_.adjusted(QUrl::RemoveFilename).toString()
          : QString();
  bool added = false;
  for (const QQmlError &warning : warnings) {
    const QString url = warning.url().toString();
    if (dir.isEmpty() || !url.startsWith(dir))
      continue;
    warnings_.append(QStringLiteral("%1:%2: %3")
                         .arg(url.mid(dir.size()))
                         .arg(warning.line())
                         .arg(warning.description()));
    added = true;
  }
  if (!added)
    return;
  if (warnings_.size() > kMaxWarnings)
    warnings_ = warnings_.mid(warnings_.size() - kMaxWarnings);
  Q_EMIT warningsChanged();
}

void DashboardSync::setSyncing(bool syncing) {
  if (syncing_ == syncing)
    return;
  syncing_ = syncing;
  Q_EMIT syncingChanged();
}

void DashboardSync::setError(const QString &error) {
  if (error_ == error)
    return;
  error_ = error;
  Q_EMIT errorChanged();
}

void DashboardSync::setLocal(const QUrl &url, const QUrl &screensaverUrl,
                             const QDateTime &syncedAt) {
  if (local_url_ == url && screensaver_url_ == screensaverUrl &&
      synced_at_ == syncedAt)
    return;
  local_url_ = url;
  screensaver_url_ = screensaverUrl;
  synced_at_ = syncedAt;
  Q_EMIT localUrlChanged();
}
