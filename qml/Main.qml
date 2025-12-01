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

    WebSocket {
        id: socket
        url: "ws://192.168.1.40:8123/api/websocket"
        onTextMessageReceived: function (message) {
            console.log(message);
        }
        onStatusChanged: if (socket.status == WebSocket.Error) {
            console.log("Error: " + socket.errorString);
        } else if (socket.status == WebSocket.Open) {
            var response = {
                type: "auth",
                access_token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiI1MmZjMThmYWU3YTc0NzhiOGY5ZDFjNDM0OGI0YmI1NCIsImlhdCI6MTcyNzgxMDMyMCwiZXhwIjoyMDQzMTcwMzIwfQ.Trt5hwKRUI3XqLJeKs4-Dm1QEpNlip7qfLJmBOB0MoY"
            };
            console.log('opened', JSON.stringify(response));
            socket.sendTextMessage(JSON.stringify(response));
        } else if (socket.status == WebSocket.Closed) {
            console.log('closed');
            messageBox.text += "\nSocket closed";
        }
        active: false
    }

    Pane {
        anchors.fill: parent
    }

    Loader {
        active: HassAPI.connected
        anchors.fill: parent
        source: controller.pathFor("default_dashboard/Dashboard.qml")
    }

    Component {
        id: settingsComponent
        Loader {}
    }

    Component.onCompleted: {
        HassAPI.connect();
    }

    BusyIndicator {
        anchors.centerIn: parent

        visible: !HassAPI.connected
    }

    Connections {
        target: controller
        onIdle: function () {}
    }
}
