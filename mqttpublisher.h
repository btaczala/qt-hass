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
// non-empty, same gating pattern as RemoteAdmin's password check.
class MqttPublisher : public QObject {
  Q_OBJECT

public:
  explicit MqttPublisher(Controler *controler, QObject *parent = nullptr);

  void start();

private:
  void publishScreensaverState(bool active);

  Controler *controler_;
  QMqttClient client_;
  QTimer reconnect_timer_;
};

#endif // MQTTPUBLISHER_H
