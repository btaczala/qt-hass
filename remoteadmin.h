#ifndef REMOTEADMIN_H
#define REMOTEADMIN_H

#include <QtCore/QJsonObject>
#include <QtCore/QObject>
#include <QtCore/QUrlQuery>
#include <QtNetwork/QTcpServer>

#include <functional>

class Controler;
class QTcpSocket;

// Minimal Fully-Kiosk-Browser-style remote admin server: GET
// /?cmd=X&password=Y[&key=...&value=...], JSON responses. See CLAUDE.md for
// the supported command table. Deliberately hand-rolled on QTcpServer rather
// than Qt6::HttpServer -- the wire protocol is GET-only with no body, and
// this avoids depending on a Qt module that isn't guaranteed to be installed
// for the pinned Qt 6.7.3 Android kit. Only starts listening if
// Controler::remoteAdminPassword() is non-empty -- an unauthenticated local
// listener is not an acceptable default.
class RemoteAdmin : public QObject {
  Q_OBJECT

public:
  explicit RemoteAdmin(Controler *controler, QObject *parent = nullptr);

  void start();

private:
  void handleNewConnection();
  void handleRequest(QTcpSocket *socket, const QByteArray &requestLine);
  void writeResponse(QTcpSocket *socket, int statusCode, const QJsonObject &body);

  QJsonObject cmdDeviceInfo(const QUrlQuery &query) const;
  QJsonObject cmdStartScreensaver(const QUrlQuery &query);
  QJsonObject cmdStopScreensaver(const QUrlQuery &query);
  QJsonObject cmdGetStringSetting(const QUrlQuery &query) const;
  QJsonObject cmdSetStringSetting(const QUrlQuery &query);
  QJsonObject cmdListSettings(const QUrlQuery &query) const;

  QTcpServer server_;
  Controler *controler_;
  QMap<QString, std::function<QJsonObject(const QUrlQuery &)>> commands_;
};

#endif // REMOTEADMIN_H
