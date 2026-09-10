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

    Pane {
        anchors.fill: parent

        Label {
            text: "connecting..."
            anchors.centerIn: parent

        }
    }

    Loader {
        active: HassAPI.connected
        anchors.fill: parent
        source: Controler.pathFor("default_dashboard/Dashboard.qml")
    }

    Component.onCompleted: {
        HassAPI.connect();
    }
}
