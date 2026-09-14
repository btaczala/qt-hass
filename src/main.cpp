#include <QApplication>
#include <QDirIterator>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>

#include "controller.h"
#ifdef QTHASS_HAS_MQTT
#include "mqttpublisher.h"
#endif
#include "remoteadmin.h"

int main(int argc, char *argv[]) {
  // QApplication rather than QGuiApplication: Qt Charts' QML types are built
  // on Graphics View, which needs the widgets application object.
  QApplication app(argc, argv);
  // Required for QSettings (Controler) and QtCore's Settings (Main.qml) to
  // share one persistent store.
  QCoreApplication::setOrganizationName("qt-hass");
  QCoreApplication::setApplicationName("qthomeassistant");
  QQmlApplicationEngine engine;

  QDirIterator it(":", QDirIterator::Subdirectories);
  // while (it.hasNext()) {
  //   qDebug() << it.next();
  // }

  qSetMessagePattern(
      "[%{time process}][%{category}][%{type}][%{file}@%{line}] %{message}");

  engine.addImportPath(":/res");
  engine.rootContext()->setContextProperty("platform", QSysInfo::productType());

  // engine.singletonInstance(), not Controler::create()/instance(): calling
  // our own registered create() directly from C++ was observed to construct
  // a *second*, separate Controler instance from whatever QML itself
  // resolves the singleton to (each internally self-consistent, but
  // disagreeing with each other) -- singletonInstance() goes through the
  // engine's own singleton registry instead, guaranteeing this is the exact
  // instance QML will use. Must be called before load(), per Qt's own
  // singleton documentation.
  Controler *controler =
      engine.singletonInstance<Controler *>("QtHomeAssistant", "Controler");

  using namespace Qt::StringLiterals;
  engine.load(QUrl(u"qrc:/res/QtHomeAssistant/qml/Main.qml"_s));

  engine.rootObjects().at(0)->installEventFilter(controler);

  RemoteAdmin remoteAdmin(controler);
  if (auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().at(0)))
    remoteAdmin.setScreenshotSource([window] { return window->grabWindow(); });
  remoteAdmin.start();

#ifdef QTHASS_HAS_MQTT
  MqttPublisher mqttPublisher(controler);
  mqttPublisher.start();
#else
  if (!controler->mqttBrokerHost().isEmpty())
    qWarning() << "MQTT_BROKER_HOST is set, but this build has no Qt MQTT "
                  "support -- screensaver state won't be published";
#endif

  return app.exec();
}
