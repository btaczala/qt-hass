import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../Hass.js" as Hass
import "../Components" as Components
import ".."

EntityBase {
    id: root
    height: 80
    width: 200

    update: function (response) {
        if (!entity_data.name) {
            friendlyNameText.text = response["attributes"].friendly_name;
        }
        stateLabel.text = response["state"];
    }

    Item {
        anchors.fill: parent

        // color: "transparent"
        // color: Qt.rgba(54 / 255, 54 / 255, 54 / 255, 0.6)
        // radius: 10

        readonly property string type: entity_data.entity.split(".")[0]
        readonly property string entity_name: entity_data.entity.split(".")[1]

        MouseArea {
            anchors.fill: parent
            onClicked: controller.requestDetails(entity_data.entity, friendlyNameText.text)
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 5

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                RowLayout {
                    anchors.fill: parent

                    Label {
                        id: friendlyNameText
                        Layout.fillWidth: true
                        text: ""
                        elide: Text.ElideRight
                    }

                    IconImage {
                        source: "qrc:/qt-hass/images/lightbulb-off.svg"
                        color: Material.foreground
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Label {
                    id: stateLabel
                    color: "white"
                }
            }
        }
    }
}
