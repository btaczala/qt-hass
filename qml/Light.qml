import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import QtHomeAssistant

EntityBase {
    id: root
    property bool on: false
    update: function (response) {
        var j = JSON.parse(response);

        if (j['type'] === 'event') {
            root.on = j['event']['data']['new_state']['state'] === 'on';
        } else {
            root.entity_data = j;
            friendlyNameText.text = j['attributes'].friendly_name;
            root.on = (j["state"] === "on");

            var color = j["attributes"].rgb_color;
            if (color) {
                console.log('color', color);
                lightIcon.color = Qt.rgba(color[0] / 255, color[1] / 255, color[2] / 255, 1);
            }

            if (root.on) {} else {
                lightIcon.color = Material.foreground;
            }
        }
    }

    Item {
        anchors.fill: parent
        ColumnLayout {
            anchors.fill: parent
            anchors.bottomMargin: 10

            Rectangle {
                id: lightIcon
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 5

                MdiIcon {
                    anchors.centerIn: parent
                    iconSize: 48
                    icon: root.on ? "mdi:lightbulb-on" : "mdi:lightbulb-off"
                }
            }

            Label {
                id: friendlyNameText
                Layout.fillWidth: true
                // text: entity_data.name ? entity_data.name : root.entity_data.entity
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.entity_data ? root.entity_data['attributes'].friendly_name : root.entity_id
            }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: {
                console.log('clicked light', root.entity_id);
                HassAPI.light(root.entity_id, !root.on);
            }
        }
    }
}
