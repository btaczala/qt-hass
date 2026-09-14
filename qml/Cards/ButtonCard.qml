import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

import QtHomeAssistant

// A Home Assistant Lovelace button card: a large icon over the entity's name.
// Tapping runs the entity's default action -- a script or scene runs, a button
// is pressed, anything else toggles.
//
//     ButtonCard { entity_id: "script.good_morning" }
EntityBase {
    id: root

    // Lovelace button options; empty means "use what Home Assistant reports".
    property string name
    property string icon
    property real iconSize: 64

    readonly property string domain: root.entity_id.split(".")[0]
    readonly property var attributes: root.entity_data?.attributes ?? ({})
    readonly property string entityState: root.entity_data?.state ?? "unknown"

    function press() {
        if (root.domain === "button" || root.domain === "input_button")
            HassAPI.callService(root.domain, "press", root.entity_id);
        else if (root.domain === "script" || root.domain === "scene")
            HassAPI.callService(root.domain, "turn_on", root.entity_id);
        else
            HassAPI.callService("homeassistant", "toggle", root.entity_id);
    }

    update: function (response) {
        root.entity_data = JSON.parse(response);
    }

    implicitWidth: 120
    implicitHeight: 120
    enabled: root.entityState !== "unavailable"
    Material.roundedScale: Material.MediumScale

    TapHandler {
        id: tap
        onTapped: root.press()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 4
        opacity: tap.pressed ? 0.6 : 1

        MdiIcon {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: true
            iconSize: Math.min(root.iconSize, parent.height - label.implicitHeight - parent.spacing)
            icon: root.icon || root.attributes.icon || "mdi:gesture-tap-button"
        }

        Label {
            id: label
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font.pixelSize: 14
            text: root.name || root.attributes.friendly_name || root.entity_id
        }
    }
}
