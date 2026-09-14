import QtQuick
import QtQuick.Controls

import QtHomeAssistant

import "WeatherFormat.js" as WeatherFormat

// One line of weather for full-screen overlays: the condition's icon, the
// temperature and condition, and today's high and low under them.
Row {
    id: root

    required property string entityId
    // Scales everything; the temperature line is this tall.
    property real fontSize: 24
    property color color: "#b0b0b0"
    property color secondaryColor: "#808080"

    readonly property string unit: weather.attributes.temperature_unit ?? "°C"
    property var today: null

    function refreshForecast() {
        HassAPI.command("call_service", {
            domain: "weather",
            service: "get_forecasts",
            target: {
                entity_id: root.entityId
            },
            service_data: {
                type: "daily"
            },
            return_response: true
        }, root, (ok, json) => {
            if (ok)
                root.today = JSON.parse(json)?.response?.[root.entityId]?.forecast?.[0] ?? null;
        });
    }

    spacing: root.fontSize * 0.5

    HassEntity {
        id: weather
        entityId: root.entityId
    }

    // Today's high and low barely move; hourly is plenty.
    Timer {
        interval: 3600000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshForecast()
    }

    Connections {
        target: HassAPI
        function onConnectedChanged() {
            if (HassAPI.connected && root.visible)
                root.refreshForecast();
        }
    }

    WeatherIcon {
        anchors.verticalCenter: parent.verticalCenter
        condition: weather.state
        size: root.fontSize * 2.2
        opacity: 0.8
    }

    Column {
        anchors.verticalCenter: parent.verticalCenter

        Label {
            text: weather.attributes.temperature !== undefined ? qsTr("%1  %2").arg(WeatherFormat.number(weather.attributes.temperature) + root.unit).arg(WeatherFormat.conditionName(weather.state)) : WeatherFormat.conditionName(weather.state)
            font.pixelSize: root.fontSize
            color: root.color
        }
        Label {
            visible: root.today !== null
            text: root.today ? qsTr("↑ %1   ↓ %2").arg(WeatherFormat.number(root.today.temperature) + root.unit).arg(root.today.templow !== undefined ? WeatherFormat.number(root.today.templow) + root.unit : "—") : ""
            font.pixelSize: root.fontSize * 0.7
            color: root.secondaryColor
        }
    }
}
