import QtCore
import QtQuick.Controls.Material

// Persisted settings that only QML reads. Main.qml owns the one instance and
// hands it to SettingsPage; separate instances don't sync live.
Settings {
    category: "ui"

    property int theme: Material.Dark
    property bool animatedBackground: true
    // Dashboard navigation bar edge: "auto" (left in landscape, top in
    // portrait), "left", "right", "top" or "bottom".
    property string navPosition: "auto"
    // Battery level in the top right corner of the dashboard and screensaver;
    // Android only (Controler.batterySupported).
    property bool showBattery: false
    // Home Assistant's notification count and its Settings badge (repairs and
    // updates) in the same corner.
    property bool showNotifications: false
    property bool showSettingsAlerts: false
}
