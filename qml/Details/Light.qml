import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "../Hass.js" as HassAPI
import "../Components" as Components
import ".." as Common
import QtQuick.Dialogs

Common.EntityBase {
    id: root

    width: 480
    height: 480

    property bool on: false
    property var currentRgbColor
    property var selectedColor
    property real brightness: 40
    property real sliderValue
    property string label
    property bool colorTemp: false
    property real colorTempMax
    property real colorTempMin

    update: function (response) {
        // console.log(JSON.stringify(response));
        root.on = response["state"] === "on";
        root.isSimpleOnOff = response["attributes"].supported_color_modes[0] === "onoff";
        if (root.isSimpleOnOff) {
            label = response["state"];
        } else {
            if (root.on) {
                label = (response["attributes"].brightness / 2.55).toFixed(0) + "%";
            } else {
                label = "off";
            }
        }
        if (response["attributes"].color_mode === "rgb") {
            if (response["attributes"].rgb_color) {
                var rgb = response["attributes"].rgb_color;
                root.currentRgbColor = Qt.rgba(rgb[0] / 255, rgb[1] / 255, rgb[2] / 255, 1);
            }
            if (response["attributes"].brightness) {
                root.brightness = response["attributes"].brightness;
            }
            sliderValue = 1 - (root.brightness / 255);
        } else if (response["attributes"].color_mode === "color_temp") {
            root.colorTemp = true;
            colorTempMin = response["attributes"].min_color_temp_kelvin;
            colorTempMax = response["attributes"].max_color_temp_kelvin;
            var input = response["attributes"].color_temp_kelvin;
            var scaled = ((input - colorTempMin) / (colorTempMax - colorTempMin));
            sliderValue = scaled;
            label = input;
        }
    }

    property bool isSimpleOnOff: false

    ColumnLayout {
        anchors.fill: parent
        Item {
            id: switch_entity
            Layout.fillWidth: true
            Layout.fillHeight: true

            Loader {
                anchors.fill: parent
                sourceComponent: root.isSimpleOnOff ? simpleSwitch : rgbComponent
            }
        }
    }

    Component {
        id: simpleSwitch
        Components.Switch {
            id: switchItem
            on_icon: "qrc:/QtHass/images/lightbulb.svg"
            off_icon: "qrc:/QtHass/images/lightbulb-off.svg"
            checked: root.on
        }
    }

    Component {
        id: rgbComponent

        ColumnLayout {

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                RowLayout {
                    anchors.fill: parent
                    Item {
                        Layout.preferredWidth: parent.width * 0.3
                        Layout.fillHeight: true
                        ColumnLayout {
                            anchors.fill: parent
                            Label {
                                id: stateLabel
                                Layout.alignment: Qt.AlignHCenter
                                // verticalAlignment: Text.AlignVCenter
                                // horizontalAlignment: Text.AlignHCenter
                                color: Material.foreground
                                text: root.label
                            }
                            Components.BrightnessSlider {
                                id: brightnessSlider

                                value: root.sliderValue
                                enabled: root.on
                                Layout.alignment: Qt.AlignHCenter
                                width: 60
                                colorTemp: root.colorTemp
                                sliderColor: {
                                    if (brightnessSlider.enabled) {
                                        return root.currentRgbColor ? root.currentRgbColor : "black";
                                    } else {
                                        return "grey";
                                    }
                                }

                                onMoved: {
                                    if (brightnessSlider.colorTemp) {
                                        var scaledBack = ((value - from) / (to - from) * (root.colorTempMax - root.colorTempMin) + root.colorTempMin).toFixed(0);
                                        HassAPI.light_update_color_temp(entity_data.entity, scaledBack);
                                    } else {
                                        var brightness = (-255 * brightnessSlider.value + 255).toFixed(0);
                                        console.log("brightness", brightness);
                                        HassAPI.light_update_brightness(entity_data.entity, brightness);
                                    }
                                }
                            }
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        GridLayout {
                            anchors.fill: parent
                            columns: 4

                            Repeater {
                                model: 19

                                Rectangle {
                                    id: predefColor
                                    width: 48
                                    height: 48
                                    radius: width / 2
                                    color: Material.color(index)

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            var color = [parseInt(predefColor.color.r * 255), parseInt(predefColor.color.g * 255), parseInt(predefColor.color.b * 255)];
                                            HassAPI.light_update_color(entity_data.entity, color);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: parent.width * 0.5
                Layout.alignment: Qt.AlignHCenter
                height: 40
                radius: 20
                color: Material.color(Material.BlueGrey)

                RowLayout {
                    anchors.fill: parent
                    IconImage {
                        Layout.leftMargin: 10
                        source: root.on ? "qrc:/QtHass/images/power-off.svg" : "qrc:/QtHass/images/power.svg"
                        sourceSize.width: 24
                        sourceSize.height: 24
                        color: Material.foreground
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                HassAPI.light_toggle(entity_data.entity);
                            }
                        }
                    }
                    Rectangle {
                        Layout.fillHeight: true
                        Layout.topMargin: 3
                        Layout.bottomMargin: 3
                        Layout.maximumWidth: 4
                        Layout.preferredWidth: 2
                        color: Material.color(Material.Grey)
                        radius: 1
                    }

                    IconImage {
                        id: brightnessIcon
                        Layout.leftMargin: 10
                        sourceSize.width: 24
                        source: "qrc:/QtHass/images/brightness.svg"
                        sourceSize.height: 24
                        color: Material.foreground
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.colorTemp = false;
                            }
                        }
                    }

                    Rectangle {
                        id: colorTempIcon
                        Layout.leftMargin: 10
                        width: 24
                        height: 24
                        radius: width / 2
                        gradient: Gradient {
                            GradientStop {
                                position: 0.0
                                color: Qt.rgba(255 / 255, 178 / 255, 111 / 255)
                            }
                            GradientStop {
                                position: 1
                                color: Qt.rgba(255 / 255, 254 / 255, 250 / 255)
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                console.log('colorTemp');
                                root.colorTemp = true;
                            }
                        }
                    }
                }
            }
        }
    }
}
