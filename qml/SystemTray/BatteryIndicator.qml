import QtQuick
import QtQuick.Controls

import QtHomeAssistant

// SystemTray's battery level: an icon (with a bolt while on power) and the
// percentage, from Controler.batteryLevel/batteryCharging, which are only ever
// known on Android.
Row {
    id: root

    property real fontSize: 14
    property color textColor
    // Below lowLevel and not on power.
    property color alertColor
    property int lowLevel: 15

    readonly property int level: Controler.batteryLevel
    readonly property bool charging: Controler.batteryCharging
    readonly property bool low: root.level >= 0 && root.level <= root.lowLevel && !root.charging

    // MDI has battery-10..90 and battery (full), but battery-charging-10..100.
    readonly property string iconName: {
        if (root.level < 0)
            return "mdi:battery-unknown";
        const tens = Math.round(root.level / 10) * 10;
        if (root.charging)
            return tens <= 0 ? "mdi:battery-charging-outline" : "mdi:battery-charging-" + tens;
        if (tens >= 100)
            return "mdi:battery";
        return tens <= 0 ? "mdi:battery-outline" : "mdi:battery-" + tens;
    }

    spacing: root.fontSize * 0.2

    MdiIcon {
        anchors.verticalCenter: parent.verticalCenter
        icon: root.iconName
        iconSize: root.fontSize * 1.4
        color: root.low ? root.alertColor : root.textColor
    }

    Label {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.level >= 0
        text: qsTr("%1%").arg(root.level)
        font.pixelSize: root.fontSize
        color: root.low ? root.alertColor : root.textColor
    }
}
