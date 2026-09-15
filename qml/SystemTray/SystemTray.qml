pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Material

import QtHomeAssistant

// A small status-bar-style pill for the corner of full-screen views (Main.qml,
// Screensaver), now that Android's own status bar is hidden. Holds a row of
// indicators (SystemTrayIndicators), each switched on by its own property;
// the pill is hidden while none is shown.
Rectangle {
    id: root

    // This device's battery (see BatteryIndicator). Consumers gate it on
    // Controler.batterySupported and the "show battery" setting.
    property bool showBattery: false
    // Home Assistant's counts, from `alerts`, each shown only while above 0:
    // notifications, and repairs plus updates (its Settings badge).
    property HassAlerts alerts: null
    property bool showNotifications: false
    property bool showSettingsAlerts: false
    // Tapping expands the pill into a SystemTrayPanel with what's behind the
    // counts, while there are any. Off on the screensaver, where a tap
    // dismisses it instead.
    property bool expandable: false

    property real fontSize: 14
    property color textColor: Material.foreground
    // For warnings, e.g. a low battery.
    property color alertColor: Material.color(Material.Red)

    // The panel draws its own copy of the pill as it grows out of it.
    readonly property bool expanded: (panel.item as SystemTrayPanel)?.visible ?? false

    visible: indicators.anyShown
    opacity: root.expanded ? 0 : 1
    implicitWidth: indicators.implicitWidth + root.fontSize * 1.2
    implicitHeight: indicators.implicitHeight + root.fontSize * 0.5
    radius: height / 2
    color: Qt.alpha(Material.background, 0.6)

    MouseArea {
        // A bit larger than the pill, which is small to hit on a touch screen.
        anchors.fill: parent
        anchors.margins: -8
        enabled: root.expandable && indicators.countsShown
        onClicked: {
            const item = panel.item as SystemTrayPanel;
            if (!item?.parent)
                return;
            // Where the pill really is: on Android the window's content can
            // sit below a top inset the overlay covers.
            const origin = root.mapToItem(item.parent, 0, 0);
            item.origin = Qt.rect(origin.x, origin.y, root.width, root.height);
            item.open();
        }
    }

    Loader {
        id: panel
        active: root.expandable

        sourceComponent: SystemTrayPanel {
            alerts: root.alerts
            showBattery: root.showBattery
            showNotifications: root.showNotifications
            showSettingsAlerts: root.showSettingsAlerts
            fontSize: root.fontSize
            textColor: root.textColor
            alertColor: root.alertColor
            pillColor: root.color
        }
    }

    SystemTrayIndicators {
        id: indicators
        anchors.centerIn: parent
        showBattery: root.showBattery
        alerts: root.alerts
        showNotifications: root.showNotifications
        showSettingsAlerts: root.showSettingsAlerts
        fontSize: root.fontSize
        textColor: root.textColor
        alertColor: root.alertColor
    }
}
