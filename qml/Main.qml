import QtQuick
import QtQuick.Controls
import QtHomeAssistant

ApplicationWindow {
    id: window
    width: 1024
    height: 800
    visible: true
    title: qsTr("Hello World")
    visibility: platform == "android" ? Window.FullScreen : Window.Windowed // qmllint disable unqualified

    // No Pane here: its opaque background would hide this one.
    background: AnimatedBackground {}

    BusyIndicator {
        anchors.centerIn: parent
        visible: !HassAPI.connected
    }

    Loader {
        active: HassAPI.connected
        anchors.fill: parent
        source: Controler.pathFor("default_dashboard/Dashboard.qml")
    }

    Screensaver {
        visible: Controler.screensaverActive
    }

    Component.onCompleted: {
        HassAPI.connect();
    }

    // Mirrors HassAPI.connected onto Controler.hassConnected -- RemoteAdmin
    // (C++) needs this for the deviceInfo command, but has no reliable way
    // to reach the live HassAPI singleton itself, so it reads through
    // Controler instead. See controller.h.
    Connections {
        target: HassAPI
        function onConnectedChanged() {
            Controler.hassConnected = HassAPI.connected;
        }
    }
}
