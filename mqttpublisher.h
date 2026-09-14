#ifndef MQTTPUBLISHER_H
#define MQTTPUBLISHER_H

#include <QtCore/QObject>
#include <QtCore/QTimer>
#include <QtMqtt/QMqttClient>

class Controler;

// Publishes this device's screensaver state to an MQTT broker in the exact
// shape Home Assistant's fully_kiosk integration expects for its "fast
// path" (entity.py's mqtt_subscribe(), see controller.h's
// kMqttEventTopicTemplate) -- so switch.barteks_mini_localdomain_wygaszacz_ekranu
// (and any other fully_kiosk entity relying on the same mechanism) updates
// immediately instead of waiting for the integration's 30s deviceInfo/
// listSettings poll. Only connects if Controler::mqttBrokerHost() is
// non-empty, same gating pattern as RemoteAdmin's password check, and
// reconnects whenever Controler's MQTT config changes.
class MqttPublisher : public QObject {
  Q_OBJECT

public:
  explicit MqttPublisher(Controler *controler, QObject *parent = nullptr);

  void start();

private:
  // Drops the current connection, if any, and starts again with the current
  // config.
  void restart();
  void publishScreensaverState(bool active);

  Controler *controler_;
  // A fresh client per start(): reusing one across a config change lets the
  // old connection's asynchronous close tear down the new connection attempt.
  QMqttClient *client_{nullptr};
  QTimer reconnect_timer_;
};

#endif // MQTTPUBLISHER_H
