#include <QDirIterator>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "controller.h"

int main(int argc, char *argv[]) {
  QGuiApplication app(argc, argv);
  QQmlApplicationEngine engine;

  QDirIterator it(":", QDirIterator::Subdirectories);
  while (it.hasNext()) {
    qDebug() << it.next();
  }

  qSetMessagePattern(
      "[%{time process}][%{category}][%{type}][%{file}@%{line}] %{message}");

  Controler *ctrl = new Controler{&engine};
  engine.addImportPath(":/res");
  engine.rootContext()->setContextProperty("controller", ctrl);
  QString platformName;
  engine.rootContext()->setContextProperty("platform", QSysInfo::productType());
  using namespace Qt::StringLiterals;
  engine.load(
      QUrl(u"qrc:/res/QtHomeAssistant/qml/main.qml"_s));

  return app.exec();
}
