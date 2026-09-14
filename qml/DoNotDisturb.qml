import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtHomeAssistant

// "Do not disturb" sign: the clock and a looping gif on black, covering
// everything -- the dashboard and the screensaver alike -- whenever `entityId`
// (e.g. an input_boolean) is on, with a button that hides it for
// snoozeMinutes. Hiding lasts until then or
// until the entity turns off, so the next do-not-disturb shows it again.
Popup {
    id: root

    required property string entityId
    property int snoozeMinutes: 1

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
    visible: entity.state === "on" && !entity.snoozed

    background: Rectangle {
        color: "black"
    }

    HassEntity {
        id: entity
        entityId: root.entityId

        // Hidden via the button.
        property bool snoozed: false

        onStateChanged: if (entity.state !== "on")
            entity.snoozed = false
    }

    Timer {
        id: snooze
        interval: root.snoozeMinutes * 60000
        onTriggered: entity.snoozed = false
    }

    Column {
        anchors.centerIn: parent
        spacing: 24

        Clock {
            anchors.horizontalCenter: parent.horizontalCenter
            size: Math.min(root.width, root.height) * 0.6
        }
        AnimatedImage {
            anchors.horizontalCenter: parent.horizontalCenter
            source: "qrc:/res/QtHomeAssistant/images/screensaver.gif"
            fillMode: Image.PreserveAspectFit
            playing: root.visible
        }
        Button {
            anchors.horizontalCenter: parent.horizontalCenter
            Material.theme: Material.Dark
            flat: true
            text: root.snoozeMinutes === 1 ? qsTr("Hide for 1 minute") : qsTr("Hide for %1 minutes").arg(root.snoozeMinutes)
            onClicked: {
                entity.snoozed = true;
                snooze.restart();
            }
        }
    }
}
