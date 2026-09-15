import QtQuick
import QtQuick.Templates as T
import QtQuick.Controls.Material

import QtHomeAssistant

// Lovelace "light-brightness" tile feature: a slider filled up to the light's
// brightness. Only shown for lights that can actually dim.
TileFeature {
    id: root

    readonly property var brightnessModes: ["brightness", "color_temp", "hs", "xy", "rgb", "rgbw", "rgbww", "white"]

    supported: root.domain === "light" && (root.attributes.supported_color_modes ?? []).some(mode => root.brightnessModes.includes(mode))

    T.Slider {
        id: slider

        anchors.fill: parent
        from: 1
        to: 100
        stepSize: 1
        snapMode: T.Slider.SnapAlways
        // Follows Home Assistant until dragged; the next pushed state re-syncs it.
        value: root.tile?.isOn ? Math.round((root.attributes.brightness ?? 0) / 2.55) : 0

        Accessible.name: qsTr("Brightness")

        onPressedChanged: {
            if (!slider.pressed)
                HassAPI.callService("light", "turn_on", root.tile.entityId, {
                    brightness_pct: slider.value
                });
        }

        background: Rectangle {
            radius: 12
            color: Qt.rgba(root.Material.foreground.r, root.Material.foreground.g, root.Material.foreground.b, 0.08)

            Rectangle {
                id: fill
                width: slider.visualPosition * parent.width
                height: parent.height
                radius: 12
                color: root.tile?.stateColor ?? "transparent"
            }

            Rectangle {
                x: Math.max(8, fill.width - width - 8)
                anchors.verticalCenter: parent.verticalCenter
                width: 4
                height: parent.height / 2
                radius: 2
                color: slider.visualPosition > 0 ? root.Material.background : root.Material.hintTextColor
            }
        }
    }
}
