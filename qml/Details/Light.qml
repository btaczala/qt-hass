import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Hass.js" as HassAPI
import "../Components" as Components
import ".." as Common

Common.EntityBase {
    id: root

    update: function (response) {
        stateLabel.text = response["state"];
        switchItem.checked = response["state"] === "on";
    }

    ColumnLayout {
        anchors.fill: parent
        Label {
            id: stateLabel
            Layout.fillWidth: true
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
        }
        Item {
            id: switch_entity
            Layout.fillWidth: true
            Layout.fillHeight: true

            Components.Switch {
                id: switchItem
                anchors.centerIn: parent
                // checked: root.entity_status["state"] === "on"
                on_icon: "qrc:/qt-hass/images/lightbulb.svg"
                off_icon: "qrc:/qt-hass/images/lightbulb-off.svg"

                onToggled: {
                    stateLabel.text = switchItem.checked ? "on" : "off";
                    // HassAPI.light_set_state(root.entity_id, checked, function (result) {
                    //         console.log("Light: ", JSON.stringify(result));
                    //     r);
                }
            }
        }
    }

    Timer {
    }
}
