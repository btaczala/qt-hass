import QtQuick
import QtQuick.Effects

Item {
    Image {
        id: sourceItem
        source: "qt_logo_green_rgb.png"
        // Hide the source item, otherwise both the source item and
        // MultiEffect will be rendered
        visible: false
        // or you can set:
        // opacity: 0
    }
    // Renders a new item with the specified effects rendered
    // at the same position where the source item was rendered
    MultiEffect {
        source: sourceItem
        anchors.fill: sourceItem
        saturation: -1.0
    }
}
