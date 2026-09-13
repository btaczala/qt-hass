import QtQuick
import QtQuick.Controls
import QtHomeAssistant

// Idle-triggered (or remotely forced, via RemoteAdmin) screensaver: dims
// everything behind it and centers a looping gif. Shown by binding `visible`
// to Controler.screensaverActive in Main.qml. Being modal, it swallows
// clicks/touches before they reach the dashboard underneath, so it has to
// dismiss itself on tap rather than rely on Controler's eventFilter
// (installed on the root window) seeing a press that never gets that far.
Popup {
    id: screensaver

    parent: Overlay.overlay
    x: 0
    y: 0
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0

    modal: true
    focus: true
    closePolicy: Popup.NoAutoClose

    background: Rectangle {
        color: "black"
        opacity: 0.85
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Controler.screensaverActive = false
    }

    AnimatedImage {
        anchors.centerIn: parent
        source: "qrc:/res/QtHomeAssistant/images/screensaver.gif"
        fillMode: Image.PreserveAspectFit
        playing: screensaver.visible
    }
}
