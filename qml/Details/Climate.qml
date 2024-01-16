import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Hass.js" as HassAPI
import ".." as Common

Common.EntityBase {
    id: root

    update: function (response) {
        dial.from = response["attributes"].min_temp;
        dial.to = response["attributes"].max_temp;
        dial.value = response["attributes"].target_temperature;
        dial.stepSize = response["attributes"].target_temp_step;
        fanModeComboBox.model = response["attributes"].fan_modes;
        modeComboBox.model = response["attributes"].hvac_modes;
        presetComboBox.model = response["attributes"].preset_modes;
    }

    ColumnLayout {
        anchors.fill: parent

        Label {
            Layout.fillWidth: true
            text: "Current temperature"
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
        }
        Label {
            Layout.fillWidth: true
            text: "Current temperature"
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
        }

        Item {
            Layout.fillHeight: true
            Layout.fillWidth: true
            Dial {
                id: dial
                width: parent.width * 0.9
                height: parent.height * 0.9
                anchors.centerIn: parent

                onValueChanged: {
                    temperatureLabel.text = dial.value.toFixed(1);
                }
                snapMode: Dial.SnapAlways
                background: Rectangle {
                    x: dial.width / 2 - width / 2
                    y: dial.height / 2 - height / 2
                    implicitWidth: 140
                    implicitHeight: 140
                    width: Math.max(64, Math.min(dial.width, dial.height))
                    height: width
                    color: "transparent"
                    radius: width / 2
                    // border.color: dial.pressed ? "#17a81a" : "#21be2b"
                    border.color: Material.foreground
                    opacity: dial.enabled ? 1 : 0.3
                }
                handle: Rectangle {
                    id: handleItem
                    x: dial.background.x + dial.background.width / 2 - width / 2
                    y: dial.background.y + dial.background.height / 2 - height / 2
                    width: 16
                    height: 16
                    // color: dial.pressed ? "#17a81a" : "#21be2b"
                    color: Material.foreground
                    radius: 8
                    antialiasing: true
                    opacity: dial.enabled ? 1 : 0.3
                    transform: [
                        Translate {
                            y: -Math.min(dial.background.width, dial.background.height) * 0.4 + handleItem.height / 2
                        },
                        Rotation {
                            angle: dial.angle
                            origin.x: handleItem.width / 2
                            origin.y: handleItem.height / 2
                        }
                    ]
                }
            }

            Label {
                id: temperatureLabel
                text: "23"
                anchors.centerIn: parent
            }
        }

        Rectangle {
            Layout.preferredHeight: 70
            Layout.fillWidth: true
            color: "green"
            GridLayout {
                anchors.fill: parent
                columns: 4
                ComboBox {
                    id: modeComboBox
                    width: 40
                    height: 40
                }
                ComboBox {
                    id: presetComboBox
                }
                ComboBox {
                    id: fanModeComboBox
                }
                ComboBox {
                }
            }
        }
    }
}
