pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtHomeAssistant

// Idle-triggered (or remotely forced, via RemoteAdmin) screensaver, dim on
// black: a clock and the weather that jump to a new random spot every minute,
// so they don't stay lit in one place long enough to burn in, above a home
// energy summary kept along the bottom edge (DoNotDisturb draws over it). Shown by binding `visible` to
// Controler.screensaverActive in Main.qml. Being modal, it
// swallows clicks/touches before they reach the dashboard underneath, so it
// has to dismiss itself on tap rather than rely on Controler's eventFilter
// (installed on the root window) seeing a press that never gets that far.
Popup {
    id: screensaver

    parent: Overlay.overlay
    x: 0
    y: 0
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    padding: 0

    modal: true
    focus: true
    closePolicy: Popup.NoAutoClose

    // Shown under the clock while connected. See WeatherSummary and
    // EnergySummary for what they read.
    required property string weatherEntity
    required property var energyEntities

    // Only while shown and connected: nothing to read otherwise.
    readonly property bool live: screensaver.visible && HassAPI.connected
    // Scales everything.
    readonly property real unit: Math.min(screensaver.width, screensaver.height)

    background: Rectangle {
        color: "black"
    }

    // Clock and weather move around together, in the room above the energy
    // summary.
    Column {
        id: panel

        // Where the panel sits, as a fraction of the room left around it, so
        // it stays fully on screen as its size or the screen's changes.
        property real fractionX: 0.5
        property real fractionY: 0.5

        function relocate() {
            panel.fractionX = Math.random();
            panel.fractionY = Math.random();
        }

        readonly property real unit: screensaver.unit
        readonly property real room: energy.visible ? energy.y - panel.unit * 0.05 : screensaver.height

        x: panel.fractionX * Math.max(0, screensaver.width - panel.width)
        y: panel.fractionY * Math.max(0, panel.room - panel.height)
        spacing: panel.unit * 0.05

        Behavior on opacity {
            NumberAnimation {
                duration: 600
            }
        }

        Clock {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            // Nothing to tap through to on a full-screen overlay.
            showWeather: false
            size: panel.unit * 0.75

            // Fades out, then jumps and fades back in. The jump is on a Timer
            // rather than at the end of the fade: animations only advance
            // while the window renders, and the jump has to happen regardless.
            onMinutePassed: {
                panel.opacity = 0;
                jump.restart();
            }
        }

        Loader {
            anchors.horizontalCenter: parent.horizontalCenter
            active: screensaver.live
            visible: active

            sourceComponent: WeatherSummary {
                entityId: screensaver.weatherEntity
                fontSize: panel.unit * 0.045
            }
        }

        Timer {
            id: jump
            interval: 600
            onTriggered: {
                panel.relocate();
                panel.opacity = 1;
            }
        }
    }

    Loader {
        id: energy
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: screensaver.unit * 0.04
        active: screensaver.live
        visible: active

        sourceComponent: EnergySummary {
            entities: screensaver.energyEntities
            fontSize: screensaver.unit * 0.036
            // Two by two unless the screen is wide enough for a row.
            columns: screensaver.width > screensaver.height * 1.5 ? 4 : 2
        }
    }

    onOpened: panel.relocate()

    MouseArea {
        anchors.fill: parent
        onClicked: Controler.screensaverActive = false
    }
}
