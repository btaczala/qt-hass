import QtQuick
import QtQuick.Controls

// Time and date in dim greys for dark full-screen overlays (Screensaver,
// DoNotDisturb). Ticks only while visible; minutePassed() fires on each new
// minute, e.g. to move the clock around.
Column {
    id: root

    // Scales the whole clock; the time is a fifth of this tall.
    property real size: 400
    property date now: new Date()

    signal minutePassed

    // Catches up straight away, e.g. when shown again after a while hidden.
    function refresh() {
        root.now = new Date();
    }

    spacing: root.size * 0.01

    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.now.toLocaleTimeString(Qt.locale(), "HH:mm")
        font.pixelSize: root.size * 0.2
        font.weight: Font.Light
        color: "#b0b0b0"
    }
    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.now.toLocaleDateString(Qt.locale(), "dddd, d MMMM")
        font.pixelSize: root.size * 0.05
        color: "#808080"
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible
        onTriggered: {
            const now = new Date();
            const minuteChanged = now.getMinutes() !== root.now.getMinutes();
            root.now = now;
            if (minuteChanged)
                root.minutePassed();
        }
    }

    onVisibleChanged: if (root.visible)
        root.refresh()
}
