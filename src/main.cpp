#include <QDirIterator>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "controller.h"

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
  using namespace Qt::StringLiterals;
  engine.load(QUrl(u"qrc:/res/QtHomeAssistant/qml/Main.qml"_s));

  engine.rootObjects().at(0)->installEventFilter(Controler::instance());

  return app.exec();
}
