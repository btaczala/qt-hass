import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

EntityBase {
    id: root
    property bool on: false
    update: function (response) {
        console.log("Light.qml: response =", JSON.stringify(response));
        var j = JSON.parse(response);
        root.entity_data = j;
        friendlyNameText.text = j['attributes'].friendly_name;
        root.on = (j["state"] === "on");
        lightIcon.source = (root.on ? "qrc:/res/QtHomeAssistant/images/lightbulb.svg" : "qrc:/res/QtHomeAssistant/images/lightbulb-off.svg");
        var color = j["attributes"].rgb_color;
        if (color) {
            lightIcon.color = Qt.rgba(color[0] / 255, color[1] / 255, color[2] / 255, 1);
        }

        // should we present dial
        dial.visible = j["attributes"].supported_color_modes[0] !== "onoff";
        if (j["attributes"].brightness) {
            dial.visible = root.on;
            if (!dial.pressed) {
                dial.value = response["attributes"].brightness;
            }
        }
        if (root.on) {} else {
            lightIcon.color = Material.foreground;
        }
    }

    Item {
        anchors.fill: parent
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
                    to: 255
                    visible: false
                    live: false
                    value: 100

                    // onValueChanged: {
                    //     Hass.light_update_brightness(entity_data.entity, dial.value);
                    // }
                }
                // IconImage {
                //     id: lightIcon
                //     color: Material.foreground
                //     sourceSize.width: 48
                //     sourceSize.height: 48
                //     anchors.centerIn: parent
                //     MouseArea {
                //         anchors.fill: parent
                //         // onClicked: {
                //         //     Hass.light_toggle(entity_data.entity);
                //         // }
                //         // onPressAndHold: {
                //         //     controller.requestDetails(entity_data.entity, friendlyNameText.text);
                //         // }
                //     }
                // }
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
    }
}
