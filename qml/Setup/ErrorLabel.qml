import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

// A setup step's error message; takes no room while empty.
Label {
    visible: text !== ""
    wrapMode: Text.WordWrap
    color: Material.color(Material.Red, Material.Shade300)
}
