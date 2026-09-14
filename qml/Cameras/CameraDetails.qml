pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import QtHomeAssistant

// A camera's scene details as small chips, for drawing over its image: motion
// now, dark or light, and how long ago motion was last seen. Chips for what
// the camera doesn't report are left out.
Row {
    id: root

    required property CameraSensors sensors
    property real fontSize: 12

    // Ticks the "ago" text along.
    property real now: Date.now()

    function ago(ms: real): string {
        const minutes = Math.floor((root.now - ms) / 60000);
        if (minutes < 1)
            return qsTr("just now");
        if (minutes < 60)
            return qsTr("%1 min ago").arg(minutes);
        if (minutes < 24 * 60)
            return qsTr("%1 h ago").arg(Math.floor(minutes / 60));
        return new Date(ms).toLocaleString(Qt.locale(), "d MMM HH:mm");
    }

    component Chip: Rectangle {
        id: chip

        property string icon
        property string text
        property color accent: "white"

        width: chipRow.implicitWidth + 12
        height: chipRow.implicitHeight + 6
        radius: height / 2
        color: Qt.rgba(0, 0, 0, 0.55)

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 4

            MdiIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: chip.icon
                iconSize: root.fontSize + 2
                color: chip.accent
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.text
                color: "white"
                font.pixelSize: root.fontSize
            }
        }
    }

    spacing: 6

    Timer {
        interval: 30000
        repeat: true
        running: root.visible
        onTriggered: root.now = Date.now()
    }
    onVisibleChanged: root.now = Date.now()

    Chip {
        visible: root.sensors.hasMotion
        icon: root.sensors.motionDetected ? "mdi:motion-sensor" : "mdi:motion-sensor-off"
        text: root.sensors.motionDetected ? qsTr("Motion") : qsTr("No motion")
        accent: root.sensors.motionDetected ? "#ff5252" : "#bdbdbd"
    }
    Chip {
        visible: root.sensors.hasDark
        icon: root.sensors.isDark ? "mdi:weather-night" : "mdi:white-balance-sunny"
        text: root.sensors.isDark ? qsTr("Dark") : qsTr("Light")
        accent: root.sensors.isDark ? "#9fa8da" : "#ffd54f"
    }
    Chip {
        visible: !root.sensors.motionDetected && !isNaN(root.sensors.lastMotion)
        icon: "mdi:history"
        text: qsTr("Last motion %1").arg(root.ago(root.sensors.lastMotion))
        accent: "#bdbdbd"
    }
}
