import QtQuick
import QtQuick.Controls.Material

import QtHomeAssistant

// SystemTray's row of indicators, shared by the pill and the header of the
// SystemTrayPanel it expands into, so the two line up exactly.
Row {
    id: root

    property bool showBattery: false
    property HassAlerts alerts: null
    property bool showNotifications: false
    property bool showSettingsAlerts: false

    property real fontSize: 14
    property color textColor: Material.foreground
    property color alertColor: Material.color(Material.Red)
    // Fades the counts, but not the battery, as the tray expands.
    property real countsOpacity: 1

    // What's shown, from these rather than the indicators' own `visible`,
    // which reads false whenever an ancestor is hidden.
    readonly property bool notificationsShown: root.showNotifications && root.alerts !== null && root.alerts.notifications > 0
    readonly property bool settingsAlertsShown: root.showSettingsAlerts && root.alerts !== null && root.alerts.settingsAlerts > 0
    readonly property bool countsShown: root.notificationsShown || root.settingsAlertsShown
    readonly property bool anyShown: root.showBattery || root.countsShown

    spacing: root.fontSize * 0.8

    CountIndicator {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.notificationsShown
        opacity: root.countsOpacity
        icon: "mdi:bell"
        count: root.alerts ? root.alerts.notifications : 0
        fontSize: root.fontSize
        textColor: root.textColor
    }

    CountIndicator {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.settingsAlertsShown
        opacity: root.countsOpacity
        icon: "mdi:cog"
        count: root.alerts ? root.alerts.settingsAlerts : 0
        fontSize: root.fontSize
        textColor: root.textColor
    }

    BatteryIndicator {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.showBattery
        fontSize: root.fontSize
        textColor: root.textColor
        alertColor: root.alertColor
    }
}
