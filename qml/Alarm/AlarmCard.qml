pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

import QtHomeAssistant

// An alarm_control_panel card: the state as a tinted shield, the name and the
// state. Tapping it opens AlarmPopup to arm or disarm it.
//
//     AlarmCard { entityId: "alarm_control_panel.home"; name: qsTr("Alarm") }
Pane {
    id: root

    required property string entityId
    // The entity's friendly name when empty.
    property string name

    readonly property alias alarm: alarm
    readonly property string displayName: root.name || (alarm.attributes.friendly_name ?? root.entityId)

    Material.elevation: 4
    Material.roundedScale: Material.MediumScale

    Accessible.role: Accessible.Button
    Accessible.name: qsTr("%1: %2").arg(root.displayName).arg(alarm.stateLabel)

    AlarmEntity {
        id: alarm
        entityId: root.entityId
    }

    TapHandler {
        onTapped: popup.open()
    }

    RowLayout {
        anchors.fill: parent
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            Layout.alignment: Qt.AlignVCenter
            radius: 20
            color: Qt.rgba(alarm.color.r, alarm.color.g, alarm.color.b, 0.2)

            Behavior on color {
                ColorAnimation {
                    duration: 200
                }
            }

            MdiIcon {
                anchors.centerIn: parent
                icon: alarm.icon
                color: alarm.color
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Label {
                Layout.fillWidth: true
                text: root.displayName
                font.pixelSize: 14
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
            Label {
                Layout.fillWidth: true
                text: alarm.stateLabel
                font.pixelSize: 12
                color: root.Material.secondaryTextColor
                elide: Text.ElideRight
            }
        }

        MdiIcon {
            Layout.alignment: Qt.AlignVCenter
            icon: "mdi:chevron-right"
            color: root.Material.hintTextColor
        }
    }

    AlarmPopup {
        id: popup
        alarm: alarm
        title: root.displayName
    }
}
