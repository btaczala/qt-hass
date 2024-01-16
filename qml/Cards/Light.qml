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
            lightIcon.source = (response["state"] === "on" ? "qrc:/qt-hass/images/lightbulb.svg" : "qrc:/qt-hass/images/lightbulb-off.svg");
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
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10

        spacing: 10

        IconImage {
            id: lightIcon
            source: "qrc:/qt-hass/images/lightbulb-off.svg"
            color: Material.foreground
        }

        Label {
            id: friendlyNameText
            Layout.fillWidth: true
            // text: entity_data.name ? entity_data.name : root.entity_data.entity
            text: root.entity_data.entity
            elide: Text.ElideRight
        }
    }
}
