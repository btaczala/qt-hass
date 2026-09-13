import QtCore
import QtQuick.Controls.Material

// Persisted settings that only QML reads. Main.qml owns the one instance and
// hands it to SettingsPage; separate instances don't sync live.
Settings {
    category: "ui"

    property int theme: Material.Dark
    property bool animatedBackground: true
}
