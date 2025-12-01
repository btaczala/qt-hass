import QtQuick
import QtQuick.Controls
import QtHomeAssistant
import QtWebSockets

ApplicationWindow {
    id: window
    width: 1024
    height: 800
    visible: true
    title: qsTr("Hello World")
    visibility: platform == "android" ? Window.FullScreen : Window.Windowed // qmllint disable unqualified

    Pane {
        anchors.fill: parent
    }

    Loader {
        active: HassAPI.connected
        anchors.fill: parent
        source: controller.pathFor("default_dashboard/Dashboard.qml")
    }
    Component.onCompleted: {
        HassAPI.connect();
    }

}
