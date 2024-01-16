#ifndef HASS

#include <QtCore/QObject>

class Hass : public QObject {
  Q_OBJECT

public:
  Hass(QObject *parent = nullptr);

public slots:
  void getStatus(QString entity_id);
};

#endif // !HASS
