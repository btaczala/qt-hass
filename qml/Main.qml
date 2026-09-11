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

    Component.onCompleted: {
        HassAPI.connect();
    }

    IconImage{}
}
