import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// One figure in an energy detail overlay: a caption, a large value, and an
// optional smaller line under it.
ColumnLayout {
    id: root

    property string label
    property string value
    property string detail
    property color color: Material.foreground

    spacing: 0

    Label {
        Layout.fillWidth: true
        text: root.label
        font.pixelSize: 12
        color: root.Material.secondaryTextColor
        elide: Text.ElideRight
    }
    Label {
        Layout.fillWidth: true
        text: root.value
        font.pixelSize: 22
        color: root.color
        elide: Text.ElideRight
    }
    Label {
        Layout.fillWidth: true
        visible: root.detail !== ""
        text: root.detail
        font.pixelSize: 11
        color: root.Material.hintTextColor
        elide: Text.ElideRight
    }
}
