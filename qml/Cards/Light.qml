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
        console.log("Light.qml:", JSON.stringify(response));
        if (!entity_data.name) {
            friendlyNameText.text = response["attributes"].friendly_name;
        }
        lightIcon.source = (response["state"] === "on" ? "qrc:/qt-hass/images/lightbulb.svg" : "qrc:/qt-hass/images/lightbulb-off.svg");
        var color = response["attributes"].rgb_color;
        if (color) {
            console.log("color", color);
            lightIcon.color = Qt.rgba(color[0] / 255, color[1] / 255, color[2] / 255, 1);
        }
    }

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
    ColumnLayout {
        anchors.fill: parent
        anchors.bottomMargin: 10

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Dial {
                anchors.fill: parent
            }
            IconImage {
                id: lightIcon
                // source: "qrc:/qt-hass/images/lightbulb-off.svg"
                color: Material.foreground
                sourceSize.width: 100
                sourceSize.height: 100
                anchors.centerIn: parent
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
