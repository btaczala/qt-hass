pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import QtHomeAssistant

import "Details/EnergyFormat.js" as EnergyFormat

// The home's energy at a glance, for full-screen overlays: solar (now, and
// today against the forecast), home consumption (now and today), battery and
// grid, each an icon over two lines. Reads the entities in `entities`:
//
//     {solarPower, homePower, gridPower (import-positive), batteryPower
//      (discharge-positive), batterySoc, solarEnergyToday, homeEnergyToday,
//      solarForecastToday}
Grid {
    id: root

    required property var entities
    // Scales everything; the value line is this tall.
    property real fontSize: 20
    property color color: "#b0b0b0"
    property color secondaryColor: "#808080"
    // Tints the icons; kept dim like the rest.
    property real iconOpacity: 0.7
    // Below this much power a battery or grid counts as idle.
    property real idleWatts: 30

    component Reading: Row {
        id: reading

        property string icon
        property color iconColor
        property string value
        property string detail

        spacing: root.fontSize * 0.4

        MdiIcon {
            anchors.verticalCenter: parent.verticalCenter
            icon: reading.icon
            iconSize: root.fontSize * 1.8
            color: reading.iconColor
            opacity: root.iconOpacity
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter

            Label {
                text: reading.value
                font.pixelSize: root.fontSize
                color: root.color
            }
            Label {
                text: reading.detail
                font.pixelSize: root.fontSize * 0.7
                color: root.secondaryColor
            }
        }
    }

    function valueOr(entity: HassEntity, format: var): string {
        return entity.available ? format(entity.baseValue) : "—";
    }

    columnSpacing: root.fontSize * 1.6
    rowSpacing: root.fontSize * 0.8

    HassEntity {
        id: solarPower
        entityId: root.entities.solarPower
    }
    HassEntity {
        id: solarToday
        entityId: root.entities.solarEnergyToday
    }
    HassEntity {
        id: solarForecast
        entityId: root.entities.solarForecastToday
    }
    HassEntity {
        id: homePower
        entityId: root.entities.homePower
    }
    HassEntity {
        id: homeToday
        entityId: root.entities.homeEnergyToday
    }
    HassEntity {
        id: batterySoc
        entityId: root.entities.batterySoc
    }
    HassEntity {
        id: batteryPower
        entityId: root.entities.batteryPower
    }
    HassEntity {
        id: gridPower
        entityId: root.entities.gridPower
    }

    Reading {
        icon: "mdi:solar-power-variant"
        iconColor: "#ff9800"
        value: root.valueOr(solarPower, EnergyFormat.power)
        detail: !solarToday.available ? "" : solarForecast.available ? qsTr("%1 of %2 today").arg(EnergyFormat.energy(solarToday.baseValue)).arg(EnergyFormat.energy(solarForecast.baseValue)) : qsTr("%1 today").arg(EnergyFormat.energy(solarToday.baseValue))
    }
    Reading {
        icon: "mdi:home-lightning-bolt"
        iconColor: "#5c9ce6"
        value: root.valueOr(homePower, EnergyFormat.power)
        detail: homeToday.available ? qsTr("%1 today").arg(EnergyFormat.energy(homeToday.baseValue)) : ""
    }
    Reading {
        readonly property real soc: batterySoc.available ? batterySoc.value : NaN
        readonly property real watts: batteryPower.available ? batteryPower.baseValue : 0

        icon: {
            if (isNaN(soc))
                return "mdi:battery-unknown";
            const step = Math.round(soc / 10) * 10;
            if (watts < -root.idleWatts)
                return step >= 100 ? "mdi:battery-charging-100" : step <= 0 ? "mdi:battery-charging-outline" : "mdi:battery-charging-" + step;
            return step >= 100 ? "mdi:battery" : step <= 0 ? "mdi:battery-outline" : "mdi:battery-" + step;
        }
        iconColor: "#4db6ac"
        value: isNaN(soc) ? "—" : qsTr("%1 %").arg(Math.round(soc))
        detail: watts < -root.idleWatts ? qsTr("Charging %1").arg(EnergyFormat.power(watts)) : watts > root.idleWatts ? qsTr("Discharging %1").arg(EnergyFormat.power(watts)) : qsTr("Idle")
    }
    Reading {
        readonly property real watts: gridPower.available ? gridPower.baseValue : NaN

        icon: watts < -root.idleWatts ? "mdi:transmission-tower-export" : watts > root.idleWatts ? "mdi:transmission-tower-import" : "mdi:transmission-tower"
        iconColor: "#488fc2"
        value: root.valueOr(gridPower, EnergyFormat.power)
        detail: isNaN(watts) ? "" : watts < -root.idleWatts ? qsTr("Exporting") : watts > root.idleWatts ? qsTr("Importing") : qsTr("Idle")
    }
}
