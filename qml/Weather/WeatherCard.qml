pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

import QtHomeAssistant

import "WeatherFormat.js" as WeatherFormat

// A weather card after weather-chart-card: the current condition and
// temperature with today's high and low, a few of the entity's attributes, and
// the daily forecast charted (WeatherForecast).
//
//     WeatherCard { entityId: "weather.pirateweather" }
//
// The forecast isn't an entity attribute any more; it's fetched with the
// weather.get_forecasts service and refreshed every `refreshMinutes`.
Pane {
    id: root

    required property string entityId
    // Shown under the condition; the entity's friendly name when empty.
    property string name
    // Attribute rows, in order; ones the entity doesn't report are skipped.
    // Known: visibility, apparent_temperature, humidity, pressure, dew_point,
    // wind_speed, uv_index, cloud_coverage.
    property var attributeRows: ["visibility", "apparent_temperature"]
    // Most forecast days shown; fewer when narrow.
    property int maxDays: 9
    property int refreshMinutes: 30

    property var forecast: []

    readonly property var attributes: entity.attributes
    readonly property string temperatureUnit: root.attributes.temperature_unit ?? "°C"
    readonly property var today: root.forecast[0] ?? null
    readonly property int shownDays: Math.max(1, Math.min(root.maxDays, root.forecast.length, Math.floor(forecastView.width / 56)))

    readonly property var rowDefinitions: ({
            visibility: {
                icon: "mdi:eye",
                label: qsTr("Visibility"),
                unit: "visibility_unit"
            },
            apparent_temperature: {
                icon: "mdi:thermometer-water",
                label: qsTr("Apparent temperature"),
                unit: "temperature_unit"
            },
            dew_point: {
                icon: "mdi:water",
                label: qsTr("Dew point"),
                unit: "temperature_unit"
            },
            humidity: {
                icon: "mdi:water-percent",
                label: qsTr("Humidity"),
                suffix: "%"
            },
            pressure: {
                icon: "mdi:gauge",
                label: qsTr("Pressure"),
                unit: "pressure_unit"
            },
            wind_speed: {
                icon: "mdi:weather-windy",
                label: qsTr("Wind speed"),
                unit: "wind_speed_unit"
            },
            uv_index: {
                icon: "mdi:sun-wireless-outline",
                label: qsTr("UV index")
            },
            cloud_coverage: {
                icon: "mdi:weather-cloudy",
                label: qsTr("Cloud coverage"),
                suffix: "%"
            }
        })
    readonly property var rows: root.attributeRows.filter(key => root.attributes[key] !== undefined && root.rowDefinitions[key]).map(key => {
            const definition = root.rowDefinitions[key];
            let unit = definition.unit ? root.attributes[definition.unit] ?? "" : definition.suffix ?? "";
            // "16.5°C" like the header, but "10 km".
            if (unit !== "" && !unit.startsWith("°"))
                unit = " " + unit;
            return {
                icon: definition.icon,
                label: definition.label,
                value: WeatherFormat.number(root.attributes[key]) + unit
            };
        })

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
            if (!ok)
                return;
            const result = JSON.parse(json);
            root.forecast = result?.response?.[root.entityId]?.forecast ?? [];
        });
    }

    padding: 20
    Material.elevation: 4
    Material.roundedScale: Material.MediumScale

    HassEntity {
        id: entity
        entityId: root.entityId
    }

    Timer {
        interval: root.refreshMinutes * 60000
        running: true
        repeat: true
        onTriggered: root.refreshForecast()
    }

    Component.onCompleted: root.refreshForecast()

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            WeatherIcon {
                condition: entity.state
                size: 64
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Label {
                    Layout.fillWidth: true
                    text: WeatherFormat.conditionName(entity.state)
                    font.pixelSize: 28
                    elide: Text.ElideRight
                }
                Label {
                    Layout.fillWidth: true
                    text: root.name || (root.attributes.friendly_name ?? "")
                    color: root.Material.secondaryTextColor
                    elide: Text.ElideRight
                }
            }
            ColumnLayout {
                spacing: 0

                Label {
                    Layout.alignment: Qt.AlignRight
                    text: root.attributes.temperature !== undefined ? WeatherFormat.number(root.attributes.temperature) + root.temperatureUnit : "—"
                    font.pixelSize: 28
                }
                Label {
                    Layout.alignment: Qt.AlignRight
                    visible: root.today !== null
                    text: root.today ? qsTr("%1 / %2").arg(WeatherFormat.number(root.today.temperature) + root.temperatureUnit).arg(root.today.templow !== undefined ? WeatherFormat.number(root.today.templow) + root.temperatureUnit : "—") : ""
                    color: root.Material.secondaryTextColor
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.rows.length > 0
            spacing: 8

            Repeater {
                model: root.rows

                delegate: RowLayout {
                    id: row
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 12

                    MdiIcon {
                        Layout.preferredWidth: 28
                        horizontalAlignment: Text.AlignHCenter
                        icon: row.modelData.icon
                        iconSize: 20
                        color: "#5c9ce6"
                    }
                    Label {
                        Layout.fillWidth: true
                        text: row.modelData.label
                        elide: Text.ElideRight
                    }
                    Label {
                        text: row.modelData.value
                    }
                }
            }
        }

        WeatherForecast {
            id: forecastView
            Layout.fillWidth: true
            Layout.fillHeight: true
            forecast: root.forecast.slice(0, root.shownDays)
            precipitationUnit: root.attributes.precipitation_unit ?? "mm"
            windSpeedUnit: root.attributes.wind_speed_unit ?? "m/s"
        }
    }
}
