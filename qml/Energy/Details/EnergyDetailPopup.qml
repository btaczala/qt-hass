import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

import QtHomeAssistant

// Modal overlay for one node of the energy flow diagram: a header with the
// node's icon and name, and `content` below it. The content only exists while
// the popup is open, so its charts don't keep updating in the background.
Popup {
    id: root

    property string title
    property string icon
    property color accent: Material.foreground
    property Component content

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(parent.width - 32, 760)
    height: Math.min(parent.height - 32, 640)
    padding: 20
    topPadding: 8
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    Material.roundedScale: Material.MediumScale

    contentItem: ColumnLayout {
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            MdiIcon {
                icon: root.icon
                iconSize: 26
                color: root.accent
            }
            Label {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: 20
                elide: Text.ElideRight
            }
            ToolButton {
                contentItem: MdiIcon {
                    icon: "mdi:close"
                }
                onClicked: root.close()
            }
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            active: root.visible
            sourceComponent: root.content
        }
    }
}
