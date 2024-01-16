#include "hass.h"

#include <QtCore/QtDebug>

Hass::Hass(QObject *parent) : QObject(parent) {}

void Hass::getStatus(QString entity_id) {
  entity_id = entity_id.replace(" ", "");
  qDebug() << "Getting status for" << entity_id;
}
