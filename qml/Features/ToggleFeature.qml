import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import QtQuick.Controls.Material

import QtHomeAssistant

// Lovelace "toggle" tile feature: an off | on segmented control, the current
// side filled with the tile's state color.
TileFeature {
    id: root

    supported: root.tile?.toggleable ?? false

    // [off, on], matching the icons the tile itself uses for this domain.
    readonly property var icons: root.tile?.domainIcons[root.domain] ?? ["mdi:power-off", "mdi:power"]
    readonly property bool isOn: root.tile?.isOn ?? false
    readonly property color fillColor: root.tile?.stateColor ?? "transparent"

    // Inline components do not see this file's ids, so everything a segment
    // shows comes in through its own properties.
    component Segment: T.AbstractButton {
        id: segment

        required property string iconName
        required property bool current
        required property color fillColor

        Layout.fillWidth: true
        Layout.fillHeight: true

        background: Rectangle {
            radius: 12
            color: segment.current ? segment.fillColor : "transparent"
        }

        contentItem: MdiIcon {
            icon: segment.iconName
            color: segment.current ? segment.Material.background : segment.Material.foreground
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Qt.rgba(root.Material.foreground.r, root.Material.foreground.g, root.Material.foreground.b, 0.08)
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Segment {
            iconName: root.icons[0]
            current: !root.isOn
            fillColor: root.fillColor
            Accessible.name: qsTr("Turn off")
            onClicked: root.tile.setOn(false)
        }

        Segment {
            iconName: root.icons[1]
            current: root.isOn
            fillColor: root.fillColor
            Accessible.name: qsTr("Turn on")
            onClicked: root.tile.setOn(true)
        }
    }
}
