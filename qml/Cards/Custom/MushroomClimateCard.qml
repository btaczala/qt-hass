import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../../Hass.js" as Hass
import "../../Components" as Components
import "../.."

EntityBase {
    id: root
    width: 200

    height: entity_data.show_temperature_control === "true" ? 110 : 60

    update: function (response) {
        if (!entity_data.name) {
            friendlyNameText.text = response["attributes"].friendly_name;
        }
        state.text = response["state"] + " - " + response["attributes"].current_temperature;
        targetTemperatureText.text = response["attributes"].target_temperature;
    }
    Item {
        anchors.fill: parent

        // color: "transparent"
        // radius: 10

        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.maximumHeight: 60
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        controller.requestDetails(entity_data.entity, friendlyNameText.text);
                    }
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    IconImage {
                        source: "qrc:/qt-hass/images/lightbulb-off.svg"
                        color: Material.foreground
                    }

                    Item {
                        Layout.fillHeight: true
                        Layout.fillWidth: true

                        ColumnLayout {
                            anchors.centerIn: parent

                            Label {
                                id: friendlyNameText
                                Layout.fillHeight: true
                                Layout.fillWidth: true
                            }
                            Label {
                                id: state
                                Layout.fillHeight: true
                                Layout.fillWidth: true
                                font.pixelSize: 10
                                color: "grey"
                            }
                        }
                    }
                }
            }
            Item {
                Layout.fillHeight: true
                Layout.fillWidth: true
                visible: entity_data.show_temperature_control === "true"

                Item {
                    // radius: 10
                    anchors.fill: parent
                    anchors.margins: 5
                    RowLayout {
                        anchors.fill: parent
                        Button {
                            text: "-"
                            flat: true

                            onClicked: {
                            }
                        }
                        Label {
                            id: targetTemperatureText
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        Button {
                            Layout.alignment: Qt.AlignVCenter
                            text: "+"
                            flat: true
                            onClicked:
                            //  lower temp by step
                            {
                            }
                        }
                    }
                }
            }
        }
    }
}
