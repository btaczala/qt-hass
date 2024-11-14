#include <QDirIterator>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "controller.h"

int main(int argc, char *argv[]) {
  QGuiApplication app(argc, argv);
  QQmlApplicationEngine engine;

  Controler ctrl;
  engine.addImportPath(":/qthomeassistant/imports");
  engine.rootContext()->setContextProperty("controller", &ctrl);
  engine.load(
      QUrl(u"qrc:/qthomeassistant/imports/QtHomeAssistant/qml/main.qml"_qs));

  return app.exec();
}
