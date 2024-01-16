#include <QGuiApplication>
#include <QQmlApplicationEngine>

#include <QQuickStyle>
#include <QtGui/QFontDatabase>
#include <QtQml/QQmlContext>

#include <QtCore/QSysInfo>

#include "controller.h"
#include "hass.h"

#include <QDirIterator>

int main(int argc, char *argv[]) {
  QGuiApplication app(argc, argv);

  QQmlApplicationEngine engine;
  const QUrl url(u"qrc:/qt-hass/qml/Main.qml"_qs);
  QObject::connect(
      &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
      []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);

  Controler controller;
  Hass hass;
  QString platformName;
  engine.rootContext()->setContextProperty("controller", &controller);
  engine.rootContext()->setContextProperty("hass", &hass);
  engine.rootContext()->setContextProperty("platform", QSysInfo::productType());

  QQuickStyle::setStyle("Material");

  engine.load(url);

  controller.init();

  app.installEventFilter(&controller);

  return app.exec();
}
