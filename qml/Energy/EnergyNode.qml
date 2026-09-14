import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

import QtHomeAssistant

// One circle of an EnergyFlowCard: an outlined circle with an icon and whatever
// value rows are declared as children, and a caption above or below it.
// Positioned by its center, since that's what the card's connector lines attach
// to.
Item {
    id: root

    property real centerX
    property real centerY
    property string label
    property string icon
    property color color: Material.foreground
    property bool labelBelow: false
    // The home circle draws its own segmented ring instead.
    property bool outlined: true
    // Whether tapping the circle emits clicked().
    property bool clickable: false

    signal clicked

    readonly property real radius: diameter / 2
    property real diameter: 90

    default property alias content: column.data

    x: centerX - radius
    y: centerY - radius
    width: diameter
    height: diameter

    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: root.labelBelow ? undefined : parent.top
        anchors.top: root.labelBelow ? parent.bottom : undefined
        anchors.bottomMargin: 6
        anchors.topMargin: 6
        text: root.label
        font.pixelSize: 13
        color: root.Material.secondaryTextColor
    }

    Rectangle {
        anchors.fill: parent
        visible: root.outlined
        radius: root.radius
        color: "transparent"
        border.width: 2
        border.color: root.color

        Behavior on border.color {
            ColorAnimation {
                duration: 300
            }
        }
    }

    TapHandler {
        enabled: root.clickable
        onTapped: root.clicked()
    }

    HoverHandler {
        enabled: root.clickable
        cursorShape: Qt.PointingHandCursor
    }

    ColumnLayout {
        id: column
        anchors.centerIn: parent
        spacing: 1

        MdiIcon {
            Layout.alignment: Qt.AlignHCenter
            icon: root.icon
            iconSize: 24
        }
    }
}
