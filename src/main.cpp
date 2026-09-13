#include <QDirIterator>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "controller.h"
#include "mqttpublisher.h"
#include "remoteadmin.h"

int main(int argc, char *argv[]) {
  QGuiApplication app(argc, argv);
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
  remoteAdmin.start();

  MqttPublisher mqttPublisher(controler);
  mqttPublisher.start();

  return app.exec();
}
