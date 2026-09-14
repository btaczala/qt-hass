pragma ComponentBehavior: Bound

import QtQuick

import QtHomeAssistant

// A Home Assistant weather condition ("partlycloudy", "rainy", ...) as colored
// MDI glyphs -- partly cloudy is a yellow sun behind a (filled) cloud.
Item {
    id: root

    property string condition
    property real size: 48

    // Each layer: MDI name, color, size and offset as fractions of `size`.
    readonly property var layers: {
        const cloud = "#eceff1";
        const sun = "#fdd835";
        switch (root.condition) {
        case "sunny":
            return [["mdi:weather-sunny", sun, 1, 0, 0]];
        case "clear-night":
            return [["mdi:weather-night", "#cfd8dc", 1, 0, 0]];
        case "partlycloudy":
            return [["mdi:weather-sunny", sun, 0.7, 0.3, -0.05], ["mdi:cloud", cloud, 0.85, -0.05, 0.12]];
        case "cloudy":
            return [["mdi:cloud", cloud, 0.9, 0, 0]];
        case "fog":
            return [["mdi:weather-fog", "#b0bec5", 1, 0, 0]];
        case "hail":
            return [["mdi:weather-hail", cloud, 1, 0, 0]];
        case "lightning":
            return [["mdi:weather-lightning", "#ffd54f", 1, 0, 0]];
        case "lightning-rainy":
            return [["mdi:weather-lightning-rainy", "#ffd54f", 1, 0, 0]];
        case "pouring":
            return [["mdi:weather-pouring", "#90caf9", 1, 0, 0]];
        case "rainy":
            return [["mdi:weather-rainy", "#90caf9", 1, 0, 0]];
        case "snowy":
            return [["mdi:weather-snowy", "#ffffff", 1, 0, 0]];
        case "snowy-rainy":
            return [["mdi:weather-snowy-rainy", "#b3e5fc", 1, 0, 0]];
        case "windy":
            return [["mdi:weather-windy", cloud, 1, 0, 0]];
        case "windy-variant":
            return [["mdi:weather-windy-variant", cloud, 1, 0, 0]];
        case "exceptional":
            return [["mdi:weather-cloudy-alert", "#ffb74d", 1, 0, 0]];
        default:
            return [["mdi:weather-cloudy", "#90a4ae", 1, 0, 0]];
        }
    }

    implicitWidth: root.size
    implicitHeight: root.size

    Repeater {
        model: root.layers

        delegate: MdiIcon {
            required property var modelData
            icon: modelData[0]
            color: modelData[1]
            iconSize: root.size * modelData[2]
            x: (root.size - width) / 2 + root.size * modelData[3]
            y: (root.size - height) / 2 + root.size * modelData[4]
        }
    }
}
