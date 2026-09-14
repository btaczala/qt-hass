pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

import QtHomeAssistant

// Floating navigation bar in the style of lovelace-navbar-card: a rounded card
// of icon buttons, docked to any edge -- a vertical rail on the left or right,
// a row at the top or bottom -- with the current page's icon in a tinted pill.
// The last button opens the settings drawer.
Pane {
    id: root

    // "left", "right", "top" or "bottom".
    property string position: "left"
    // [{icon, label}], one per page.
    property var items: []
    property int currentIndex: 0

    readonly property bool vertical: root.position === "left" || root.position === "right"

    signal menuRequested

    padding: 6
    Material.elevation: 6
    Material.roundedScale: Material.LargeScale

    component NavButton: AbstractButton {
        id: button

        // MDI name, e.g. "mdi:cog".
        property string iconName

        implicitWidth: 72
        implicitHeight: 60
        focusPolicy: Qt.NoFocus
        Accessible.role: Accessible.PageTab
        Accessible.name: button.text

        contentItem: Item {
            Rectangle {
                id: pill
                anchors.horizontalCenter: parent.horizontalCenter
                y: 4
                width: 56
                height: 30
                radius: height / 2
                color: button.checked ? Qt.rgba(root.Material.accentColor.r, root.Material.accentColor.g, root.Material.accentColor.b, 0.25) : button.pressed ? Qt.rgba(root.Material.foreground.r, root.Material.foreground.g, root.Material.foreground.b, 0.12) : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }

                MdiIcon {
                    anchors.centerIn: parent
                    icon: button.iconName
                    iconSize: 22
                    color: button.checked ? root.Material.accentColor : root.Material.foreground
                }
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: pill.bottom
                anchors.topMargin: 2
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: button.text
                font.pixelSize: 11
                font.weight: button.checked ? Font.DemiBold : Font.Normal
                color: button.checked ? root.Material.foreground : root.Material.secondaryTextColor
            }
        }
    }

    GridLayout {
        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rows: root.vertical ? -1 : 1
        columns: root.vertical ? 1 : -1
        rowSpacing: 2
        columnSpacing: 2

        Repeater {
            model: root.items

            delegate: NavButton {
                required property var modelData
                required property int index
                iconName: modelData.icon
                text: modelData.label
                checked: index === root.currentIndex
                onClicked: root.currentIndex = index
            }
        }

        Rectangle {
            Layout.preferredWidth: root.vertical ? 40 : 1
            Layout.preferredHeight: root.vertical ? 1 : 40
            Layout.alignment: Qt.AlignCenter
            Layout.margins: 4
            color: root.Material.dividerColor
        }

        NavButton {
            iconName: "mdi:cog"
            text: qsTr("Settings")
            onClicked: root.menuRequested()
        }
    }
}
