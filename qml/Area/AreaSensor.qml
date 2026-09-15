pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

import QtHomeAssistant

// One sensor of an AreaCard on a single line: its icon and its state with the
// unit. Tapping it opens the entity's details.
//
//     AreaSensor { entityId: "sensor.office_temperature" }
RowLayout {
    id: root

    required property string entityId
    // Empty means the entity's own icon, else one for its device class.
    property string icon
    property color color: root.Material.foreground

    readonly property string domain: root.entityId.split(".")[0]
    readonly property string deviceClass: entity.attributes.device_class ?? ""

    // Home Assistant's default icons per device class: one for sensors, and
    // [off, on] for binary sensors.
    readonly property var sensorIcons: ({
            battery: "mdi:battery",
            carbon_dioxide: "mdi:molecule-co2",
            current: "mdi:current-ac",
            energy: "mdi:lightning-bolt",
            humidity: "mdi:water-percent",
            illuminance: "mdi:brightness-5",
            pm25: "mdi:molecule",
            power: "mdi:flash",
            pressure: "mdi:gauge",
            temperature: "mdi:thermometer",
            voltage: "mdi:sine-wave"
        })
    readonly property var binarySensorIcons: ({
            door: ["mdi:door-closed", "mdi:door-open"],
            garage_door: ["mdi:garage", "mdi:garage-open"],
            moisture: ["mdi:water-off", "mdi:water"],
            motion: ["mdi:motion-sensor-off", "mdi:motion-sensor"],
            occupancy: ["mdi:home-outline", "mdi:home"],
            opening: ["mdi:square-outline", "mdi:square"],
            presence: ["mdi:home-outline", "mdi:home"],
            window: ["mdi:window-closed", "mdi:window-open"]
        })
    // [off, on] labels for binary sensors, as Home Assistant words them.
    readonly property var binarySensorLabels: ({
            door: [qsTr("Closed"), qsTr("Open")],
            garage_door: [qsTr("Closed"), qsTr("Open")],
            moisture: [qsTr("Dry"), qsTr("Wet")],
            motion: [qsTr("Clear"), qsTr("Detected")],
            occupancy: [qsTr("Clear"), qsTr("Detected")],
            opening: [qsTr("Closed"), qsTr("Open")],
            presence: [qsTr("Away"), qsTr("Home")],
            window: [qsTr("Closed"), qsTr("Open")]
        })

    readonly property string resolvedIcon: {
        if (root.icon)
            return root.icon;
        if (entity.attributes.icon)
            return entity.attributes.icon;
        if (root.domain === "binary_sensor")
            return root.binarySensorIcons[root.deviceClass]?.[entity.state === "on" ? 1 : 0] ?? (entity.state === "on" ? "mdi:checkbox-marked-circle" : "mdi:radiobox-blank");
        return root.sensorIcons[root.deviceClass] ?? "mdi:eye";
    }

    readonly property string stateText: {
        if (entity.state === "")
            return "";
        if (entity.state === "unavailable")
            return qsTr("Unavailable");
        if (entity.state === "unknown")
            return qsTr("Unknown");
        if (root.domain === "binary_sensor")
            return root.binarySensorLabels[root.deviceClass]?.[entity.state === "on" ? 1 : 0] ?? (entity.state === "on" ? qsTr("On") : qsTr("Off"));
        const unit = entity.attributes.unit_of_measurement ?? "";
        let text = entity.state;
        if (!isNaN(entity.value)) {
            // Readings like 25.300001: at most two decimals, trailing zeros dropped.
            const rounded = Math.round(entity.value * 100) / 100;
            const decimals = Math.min(2, String(rounded).split(".")[1]?.length ?? 0);
            text = rounded.toLocaleString(Qt.locale(), "f", decimals);
        }
        return unit ? qsTr("%1 %2").arg(text).arg(unit) : text;
    }

    spacing: 4

    HassEntity {
        id: entity
        entityId: root.entityId
    }

    TapHandler {
        onTapped: Controler.requestDetails(root.entityId, "")
    }

    MdiIcon {
        icon: root.resolvedIcon
        iconSize: 18
        color: root.color
    }

    Label {
        text: root.stateText
        font.pixelSize: 14
        color: root.color
    }
}
