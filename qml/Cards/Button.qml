import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../Hass.js" as Hass
import "../Components" as Components
import ".."

EntityBase {
    id: root
    height: 120
    width: 120

    update: function (response) {
        if (!entity_data.name) {
            friendlyNameText.text = response["attributes"].friendly_name;
        }
    }

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
                source: "qrc:/QtHass/images/lightbulb-off.svg"
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
