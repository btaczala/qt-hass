import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import QtCore

Pane {
    id: root
    Material.elevation: 6

    signal closed
    signal themeChanged(int index)
    signal screenSaver(string screensaver)

    ColumnLayout {
        anchors.fill: parent
        TabBar {
            Material.background: Material.Blue
            Layout.fillWidth: true
            // Layout.preferredHeight: 80
            TabButton {
                text: "back"

                onClicked: closed()
            }
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            GridLayout {
                anchors.fill: parent
                anchors.margins: 10
                columns: 2

                // columnSpacing: 0

                Label {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    verticalAlignment: Text.AlignVCenter
                    text: "Screensaver"
                }

                ComboBox {
                    Layout.preferredHeight: 60
                    model: ["Clock", "Black", "None"]

                    Component.onCompleted: {
                        var index = 0;
                        for (var entry of model) {
                            console.log(entry, AppSettings.currentScreenSaver)
                            if (entry === AppSettings.currentScreenSaver) {
                                console.log("setting currentIndex to", index);
                                currentIndex = index;
                                break;
                            }
                            index++;
                        }
                    }

                    onActivated: {
                        root.screenSaver(currentText);
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "black"
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "black"
                }
                Label {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    verticalAlignment: Text.AlignVCenter
                    // horizontalAlignment: Text.AlignHCenter
                    text: "Theme"
                }

                ComboBox {
                    Layout.preferredHeight: 60
                    model: ["Light", "Dark", "System"]


                    onActivated: {
                        root.themeChanged(currentIndex);
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "black"
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "black"
                }
                Label {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    verticalAlignment: Text.AlignVCenter
                    text: "Home Assistant address"
                }

                TextField {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    placeholderText: qsTr("Enter homeassistant address")
                }
                Label {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    verticalAlignment: Text.AlignVCenter
                    text: "Path to configuration file"
                }

                TextField {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    text: controller.configurationPath
                    placeholderText: qsTr("Configuration file path")
                }
            }
        }
    }
}
