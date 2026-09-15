import QtQuick
import QtQuick.Controls

import QtHomeAssistant

// A SystemTray icon with a count next to it, e.g. Home Assistant notifications.
Row {
    id: root

    property string icon
    property int count: 0
    property real fontSize: 14
    property color textColor

    spacing: root.fontSize * 0.2

    MdiIcon {
        anchors.verticalCenter: parent.verticalCenter
        icon: root.icon
        iconSize: root.fontSize * 1.4
        color: root.textColor
    }

    Label {
        anchors.verticalCenter: parent.verticalCenter
        text: root.count
        font.pixelSize: root.fontSize
        color: root.textColor
    }
}
