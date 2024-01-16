import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../Hass.js" as Hass
import "../Components" as Components
import ".."

EntityBase {
    id: root
    height: 200
    width: 200
    update: function (response) {
        if (!entity_data.name) {
            friendlyNameText.text = response["attributes"].friendly_name;
        }
        lightIcon.source = (response["state"] === "on" ? "qrc:/qt-hass/images/lightbulb.svg" : "qrc:/qt-hass/images/lightbulb-off.svg");
        var color = response["attributes"].rgb_color;
        if (color) {
            lightIcon.color = Qt.rgba(color[0] / 255, color[1] / 255, color[2] / 255, 1);
        }
        if (response["attributes"].brightness) {
            dial.visible = true;
            if (!dial.pressed) {
                dial.value = response["attributes"].brightness;
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.bottomMargin: 10

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Dial {
                id: dial
                anchors.fill: parent
                from: 0
                to: 100
                visible: false

                onValueChanged: {
                    Hass.light_update_brightness(entity_data.entity, dial.value);
                }
            }
            IconImage {
                id: lightIcon
                // source: "qrc:/qt-hass/images/lightbulb-off.svg"
                color: Material.foreground
                sourceSize.width: 100
                sourceSize.height: 100
                anchors.centerIn: parent
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (entity_data.tap_action) {
                            if (entity_data.tap_action === "toggle")
                            // TODO: IMPLEMENT ME
                            {
                            }
                        } else {
                            controller.requestDetails(entity_data.entity, friendlyNameText.text);
                        }
                    }
                }
            }
        }

        Label {
            id: friendlyNameText
            Layout.fillWidth: true
            text: entity_data.name ? entity_data.name : root.entity_data.entity
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }
}
