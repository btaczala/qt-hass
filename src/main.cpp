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
  QApplication app(argc, argv);
  QCoreApplication::setOrganizationName("qthass");
  QCoreApplication::setApplicationName("QtHass");
  QQmlApplicationEngine engine;

  qSetMessagePattern(
      "[%{time process}][%{category}][%{type}][%{file}@%{line}] %{message}");

  engine.addImportPath(":/res");
  engine.rootContext()->setContextProperty("platform", QSysInfo::productType());

  auto *controler =
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
