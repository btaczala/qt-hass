pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import QtQuick.Controls.Material

import QtHomeAssistant

// A row of buttons, each pressing an entity -- Lovelace's "button" tile feature
// with no entries, a service-call-style row of shortcuts with them:
//
//     ButtonsFeature {}    // one "Press" button for the tile's own entity
//     ButtonsFeature {
//         outlined: true
//         entries: [{ entity_id: "button.vacuum_quick", icon: "mdi:vacuum", label: "Quick" }]
//     }
//
// An entry's entity_id, icon and label are all optional: the entity defaults
// to the tile's own, the label to "Press".
TileFeature {
    id: root

    property var entries: [{}]
    // Outlined buttons instead of filled ones.
    property bool outlined: false

    readonly property color foreground: root.Material.foreground

    function press(entityId) {
        const domain = entityId.split(".")[0];
        if (domain === "button" || domain === "input_button")
            HassAPI.callService(domain, "press", entityId);
        else if (domain === "script" || domain === "scene")
            HassAPI.callService(domain, "turn_on", entityId);
        else
            HassAPI.callService("homeassistant", "toggle", entityId);
    }

    RowLayout {
        anchors.fill: parent
        spacing: 12

        Repeater {
            model: root.entries

            T.AbstractButton {
                id: button

                required property var modelData

                Layout.fillWidth: true
                Layout.fillHeight: true
                // Equal shares of the row, whatever each label's length.
                Layout.preferredWidth: 1

                Accessible.name: contentLabel.text
                onClicked: root.press(button.modelData.entity_id || root.tile.entity_id)

                background: Rectangle {
                    radius: root.outlined ? height / 2 : 12
                    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, button.pressed ? 0.16 : root.outlined ? 0 : 0.08)
                    border.width: root.outlined ? 1 : 0
                    border.color: root.Material.hintTextColor
                }

                contentItem: Item {
                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        MdiIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !!button.modelData.icon
                            icon: button.modelData.icon ?? ""
                            iconSize: 20
                        }

                        T.Label {
                            id: contentLabel
                            anchors.verticalCenter: parent.verticalCenter
                            text: button.modelData.label ?? qsTr("Press")
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: root.foreground
                        }
                    }
                }
            }
        }
    }
}
