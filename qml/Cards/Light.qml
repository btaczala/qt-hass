import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls.Material
import "../Hass.js" as Hass
import "../Components" as Components
import ".."

EntityBase {
    id: root
    height: 220
    width: 220
    property bool on: false
    update: function (response) {
        console.log("Light.qml: response =", JSON.stringify(response));
        if (!entity_data.name) {
            friendlyNameText.text = response["attributes"].friendly_name;
        }
        root.on = (response["state"] === "on");
        lightIcon.source = (root.on ? "qrc:/QtHass/images/lightbulb.svg" : "qrc:/QtHass/images/lightbulb-off.svg");
        var color = response["attributes"].rgb_color;
        if (color) {
            lightIcon.color = Qt.rgba(color[0] / 255, color[1] / 255, color[2] / 255, 1);
        }

        // should we present dial
        dial.visible = response["attributes"].supported_color_modes[0] !== "onoff";
        if (response["attributes"].brightness) {
            dial.visible = root.on;
            if (!dial.pressed) {
                dial.value = response["attributes"].brightness;
            }
        }
        if (root.on) {
        } else {
            lightIcon.color = Material.foreground;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.bottomMargin: 10

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            Dial {
                id: dial
                anchors.fill: parent
                from: 0
                to: 255
                visible: false
                live: false

                onValueChanged: {
                    Hass.light_update_brightness(entity_data.entity, dial.value);
                }
            }
            IconImage {
                id: lightIcon
                color: Material.foreground
                sourceSize.width: 48
                sourceSize.height: 48
                anchors.centerIn: parent
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        Hass.light_toggle(entity_data.entity);
                    }
                    onPressAndHold: {
                        controller.requestDetails(entity_data.entity, friendlyNameText.text);
                    }
                }
            }
        }

        Label {
            id: friendlyNameText
            Layout.fillWidth: true
            // text: entity_data.name ? entity_data.name : root.entity_data.entity
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }
}
