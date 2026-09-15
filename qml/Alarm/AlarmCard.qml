import QtQuick

import QtHomeAssistant

// An alarm_control_panel tile: the state as a tinted shield, the name and the
// state. Everything else is Tile's, actions included, so by default tapping it
// opens the details overlay, which shows AlarmControls to arm or disarm it.
//
//     AlarmCard { entityId: "alarm_control_panel.home"; name: qsTr("Alarm") }
Tile {
    id: root

    readonly property alias alarm: alarm

    icon: alarm.icon
    stateColor: alarm.color
    stateDisplay: alarm.stateLabel

    AlarmEntity {
        id: alarm
        entityId: root.entityId
    }
}
