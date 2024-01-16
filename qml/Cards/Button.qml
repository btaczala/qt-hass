import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../Hass.js" as Hass
import "../Components" as Components

Rectangle {
    id: root
    property var entity_data: QtObject {
        property string entity: "light.main"
    }

    readonly property string entity_type: {
        var str2 = entity_data.entity.split(".")[0];
        str2 = str2.charAt(0).toUpperCase() + str2.slice(1);
        return str2;
    }
    Component.onCompleted: {
        Hass.register_handler_for_state_updates(entity_data.entity, function (response) {
                if (!entity_data.name) {
                    friendlyNameText.text = response["attributes"].friendly_name;
                }
            });
        Hass.request_update_state(entity_data.entity);
    }

    // color: "transparent"
    color: Qt.rgba(54 / 255, 54 / 255, 54 / 255, 0.6)
    radius: 10

    readonly property string type: entity_data.entity.split(".")[0]
    readonly property string entity_name: entity_data.entity.split(".")[1]
    height: 200
    width: 200

    MouseArea {
        anchors.fill: parent

        onClicked:
        // TODO: toggle
        {
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 5

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Image {
                source: "qrc:/qt-hass/images/lightbulb-off.svg"
                anchors.centerIn: parent
            }
        }

        Label {
            id: friendlyNameText
            Layout.fillWidth: true
            Layout.preferredHeight: 40

            color: "white"
            text: "state"
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }
}
