import QtQuick
import QtQuick.Controls
import QtHomeAssistant

// Idle-triggered (or remotely forced, via RemoteAdmin) screensaver: a clock on
// black that jumps to a new random spot every minute, so nothing stays lit in
// one place long enough to burn in (DoNotDisturb draws over it). Shown by
// binding `visible` to Controler.screensaverActive in Main.qml. Being modal, it
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

    background: Rectangle {
        color: "black"
    }

    Clock {
        id: clock
        // Nothing to tap through to on a full-screen overlay.
        showWeather: false

        // Where the clock sits, as a fraction of the room left around it, so
        // it stays fully on screen as its size or the screen's changes.
        property real fractionX: 0.5
        property real fractionY: 0.5

        function relocate() {
            clock.fractionX = Math.random();
            clock.fractionY = Math.random();
        }

        x: clock.fractionX * Math.max(0, screensaver.width - clock.width)
        y: clock.fractionY * Math.max(0, screensaver.height - clock.height)
        size: Math.min(screensaver.width, screensaver.height)

        // Fades out, then jumps and fades back in. The jump is on a Timer
        // rather than at the end of the fade: animations only advance while
        // the window renders, and the jump has to happen regardless.
        onMinutePassed: {
            clock.opacity = 0;
            jump.restart();
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 600
            }
        }

        Timer {
            id: jump
            interval: 600
            onTriggered: {
                clock.relocate();
                clock.opacity = 1;
            }
        }
    }

    onOpened: clock.relocate()

    MouseArea {
        anchors.fill: parent
        onClicked: Controler.screensaverActive = false
    }
}
