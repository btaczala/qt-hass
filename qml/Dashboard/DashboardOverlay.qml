import QtQuick
import QtQuick.Controls

// A full-screen overlay a dashboard shows on demand: while `active`, it covers
// everything, the screensaver included. It isn't a page, so it has no NavBar
// button; declare it anywhere in a dashboard and bind `active` to whatever
// should show it:
//
//     DashboardOverlay {
//         active: busy.state === "on"
//         HassEntity { id: busy; entityId: "input_boolean.busy" }
//         Label { anchors.centerIn: parent; text: "Busy" }
//     }
Popup {
    id: root

    property bool active: false

    parent: Overlay.overlay
    x: 0
    y: 0
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    padding: 0
    // Above the screensaver.
    z: 1

    modal: true
    dim: false
    closePolicy: Popup.NoAutoClose
    visible: root.active

    background: Rectangle {
        color: "black"
    }
}
