import QtQuick
import QtQuick.Controls.Material

import QtHomeAssistant

// A Material Design Icon, addressed by the same name Home Assistant uses.
//
//     MdiIcon { icon: "mdi:lightbulb-on"; iconSize: 48; color: "orange" }
//
// It is a Text, so color, opacity and `Behavior on color` all work as usual.
Text {
    id: root

    // "mdi:lightbulb-on" or a bare "lightbulb-on". Empty renders nothing.
    property string icon
    // Named iconSize, not size, to avoid shadowing anything on Item.
    property real iconSize: 24

    // Qt ignores a non-positive pixelSize and falls back to the default font size,
    // so an iconSize that is transiently 0 -- a binding on a width that has not
    // been laid out yet -- would flash a full-size glyph. Clamp to 1px instead.
    readonly property real pixelSize: Math.max(1, root.iconSize)

    text: Mdi.glyph(root.icon)
    font.family: Mdi.fontFamily
    font.pixelSize: root.pixelSize
    color: Material.foreground

    // MDI glyphs are drawn on a 24x24 em box with a 1em advance, so the implicit
    // width already comes out at iconSize. Pinning the line height makes the
    // implicit height match instead of picking up the font's ascent and descent,
    // which is what keeps the item square inside a Layout.
    lineHeightMode: Text.FixedHeight
    lineHeight: root.pixelSize
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    antialiasing: true
}
