import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "Hass.js" as HassLLApi

ApplicationWindow {
    id: window
    width: 480
    height: 480
    visible: true
    title: qsTr("Hello World")
    visibility: platform == "android" ? Window.FullScreen : Window.Windowed // qmllint disable unqualified

    Material.accent: Material.LightBlue
    Material.theme: Material.System

    property var idleItem

    Component.onCompleted: {
        HassLLApi.register_handler_for_state_updates(function (response) {
                // console.log("Got update for", response["entity_id"]);
                controller.hassApiRequestDataUpdated(response["entity_id"], response);
            }, "Main.qml");
    }

    // Image {
    //     anchors.fill: parent
    //     source: "qrc:/qt-hass/homekit-bg-blue-red.jpg"
    // }

    Drawer {
        id: drawer
        width: 0.66 * window.width
        height: window.height

        ColumnLayout {
            anchors.fill: parent

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 80
                Layout.leftMargin: 10
                color: "green"

                Label {
                    text: "Settings"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        drawer.close();
                        mainItem.push(settingsComponent);
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: "black"
            }
        }
    }

    StackView {
        id: mainItem
        anchors.fill: parent
        pushEnter: Transition {
            PropertyAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: 200
            }
        }
        pushExit: Transition {
            PropertyAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: 200
            }
        }
        popEnter: Transition {
            PropertyAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: 200
            }
        }
        popExit: Transition {
            PropertyAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: 200
            }
        }

        initialItem: Loader {
            id: dashboardLoader
        }
    }

    Component {
        id: settingsComponent
        Settings {

            onClosed: {
                mainItem.pop();
            }

            onThemeChanged: function (index) {
                console.log("Changing them to ", index);
                window.Material.theme = index;
            }
        }
    }
    Component {
        id: idleComponent
        Clock {
        }
    }

    IconImage {
        width: 32
        height: 32
        source: "qrc:/qt-hass/images/drawer.svg"
        color: Material.foreground
        MouseArea {
            anchors.fill: parent
            onClicked: drawer.open()
        }
        anchors.right: parent.right
        anchors.bottom: parent.bottom
    }

    Connections {
        target: controller // qmllint disable unqualified

        function onIdle(is_idle) {
            if (is_idle) {
                window.idleItem = mainItem.push(idleComponent);
            } else {
                if (mainItem.currentItem === window.idleItem) {
                    mainItem.pop();
                }
            }
        }

        function onRequestDetails(entity_id: string, friendly_name: string) {
            detailsPopup.openDetails(entity_id, friendly_name);
        }

        function onConfigurationChanged(configuration: var) {
            console.log("Dashboard: config changed");
            dashboardLoader.setSource("qrc:/qt-hass/qml/Dashboard.qml", {
                    configuration: configuration
                });
        }

    }

    DetailsPopup {
        id: detailsPopup
        opacity: 0.8
        closePolicy: Popup.CloseOnPressOutside
        modal: true
        width: parent.width * 0.9
        height: parent.width * 0.9
        focus: true
        anchors.centerIn: parent
    }
}
