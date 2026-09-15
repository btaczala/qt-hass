pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import QtHomeAssistant

// The area panel's screensaver, named in index.json next to main.qml: the
// time over each room's temperature, dim on the app's black screensaver
// background. The app fills the screen with it and keeps tap to dismiss; like
// the built-in one, it moves every minute so nothing stays lit in one place.
Item {
    id: root

    readonly property real unit: Math.min(root.width, root.height)
    readonly property color dim: "#909090"

    // Where the block sits, as a fraction of the room around it.
    property real fractionX: Math.random()
    property real fractionY: Math.random()

    ColumnLayout {
        id: block

        x: root.fractionX * Math.max(0, root.width - block.width)
        // Below the system tray's corner, which the app draws on top.
        y: root.unit * 0.1 + root.fractionY * Math.max(0, root.height - root.unit * 0.1 - block.height)
        spacing: root.unit * 0.04

        Behavior on opacity {
            NumberAnimation {
                duration: 600
            }
        }

        Clock {
            Layout.alignment: Qt.AlignHCenter
            size: root.unit * 0.5
            showWeather: false
            color: root.dim
            onMinutePassed: {
                block.opacity = 0;
                jump.restart();
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: root.unit * 0.06

            Repeater {
                model: [
                    {
                        name: "Salon",
                        entityId: "sensor.pod_oknem_temperature"
                    },
                    {
                        name: "Kuchnia",
                        entityId: "sensor.kitchen_temperature"
                    },
                    {
                        name: "Pralnia",
                        entityId: "sensor.presence_sensor_pralnia_temperatura"
                    }
                ]

                ColumnLayout {
                    id: room

                    required property var modelData

                    spacing: 0

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: room.modelData.name
                        color: root.dim
                        font.pixelSize: root.unit * 0.03
                    }

                    AreaSensor {
                        Layout.alignment: Qt.AlignHCenter
                        entityId: room.modelData.entityId
                        color: root.dim
                        // No details on tap: any tap dismisses the screensaver.
                        enabled: false
                    }
                }
            }
        }
    }

    // The jump waits out the fade on a Timer: animations only run while the
    // window renders.
    Timer {
        id: jump
        interval: 600
        onTriggered: {
            root.fractionX = Math.random();
            root.fractionY = Math.random();
            block.opacity = 1;
        }
    }
}
