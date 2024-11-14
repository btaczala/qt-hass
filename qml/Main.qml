import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "Hass.js" as HassLLApi
// import QtCore
// import QtHassComponents as C

ApplicationWindow {
    id: window
    width: 800
    height: 600
    visible: true
    title: qsTr("Hello World")
    visibility: platform == "android" ? Window.FullScreen : Window.Windowed // qmllint disable unqualified

    property var idleItem

    Material.theme: Material.Dark

    Component.onCompleted: {
        HassLLApi.register_handler_for_state_updates(function (response) {
                controller.hassApiRequestDataUpdated(response["entity_id"], response);
            }, "Main.qml");
    }

    Image {
        anchors.fill: parent
        source: "qrc:/QtHass/homekit-bg-blue-red.jpg"
    }

    Drawer {
        id: drawer
        width: 0.3 * window.width
        height: window.height

        ColumnLayout {
            anchors.fill: parent

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                Layout.leftMargin: 10

                Label {
                    anchors.fill: parent
                    // horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
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
                Layout.preferredHeight: 50
                Layout.leftMargin: 10
                color: "transparent"

                Label {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: "Screensaver"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        drawer.close();
                        window.idleItem = mainItem.push(idleComponent);
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                Layout.leftMargin: 10
                color: "transparent"

                Label {
                    anchors.fill: parent
                    // horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "About"
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: "black"
            }
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }

    Item {
        anchors.fill: parent
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
                source: "qrc:/QtHass/qml/Dashboard.qml"
            }
        }
    }

    Component {
        id: settingsComponent
        SettingsMenu {

            onClosed: {
                mainItem.pop();
            }

            onThemeChanged: function (index) {
                console.log("Changing them to ", index);
                window.Material.theme = index;
            }

            onScreenSaver: function (label) {
                AppSettings.currentScreenSaver = label;
            }
        }
    }
    Component {
        id: idleComponent
        Loader {
            source: "qrc:/QtHass/qml/Screensavers/" + AppSettings.currentScreenSaver + ".qml"
        }
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
            dashboardLoader.setSource("qrc:/QtHass/qml/Dashboard.qml", {
                    configuration: configuration
                });
        }
    }

    DetailsPopup {
        id: detailsPopup
        opacity: 0.4
        closePolicy: Popup.CloseOnPressOutside
        modal: true
        width: parent.width * 0.9
        height: parent.width * 0.9
        focus: true
        anchors.centerIn: parent
    }
}
