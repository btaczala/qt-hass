import QtQuick
import QtQuick.Controls
import QtHomeAssistant

ApplicationWindow {
    id: window
    width: 800
    height: 600
    visible: true
    title: qsTr("Hello World")
    visibility: platform == "android" ? Window.FullScreen : Window.Windowed // qmllint disable unqualified

    Loader {
        anchors.fill: parent
        source: controller.pathFor("default_dashboard/Dashboard.qml")
    }

    Component {
        id: idleComponent
    }
}
