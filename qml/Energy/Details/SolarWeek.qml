pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtCharts

import QtHomeAssistant

import "EnergyFormat.js" as EnergyFormat

// This week of solar production, for SolarDetail's tabs: what's produced so
// far and what's still expected, and each day's production next to its
// forecast -- the days ahead with the forecast alone.
ColumnLayout {
    id: root

    // [{day: midnight in ms, energy: Wh (NaN for days ahead), forecast: Wh
    // (NaN if unknown)}], one per day of the week.
    property var days: []
    // Today's midnight in ms, which of `days` is today.
    property real today: 0
    // Today's forecast up to now, and what it still expects (Wh).
    property real todayForecastSoFar: 0
    property real todayRemaining: 0
    property color color: "#ff9800"

    readonly property int todayIndex: root.days.findIndex(d => d.day === root.today)
    readonly property real produced: root.days.reduce((sum, d) => sum + (isNaN(d.energy) ? 0 : d.energy), 0)
    // The forecast for the week up to now: past days in full, today so far.
    readonly property real forecastSoFar: root.days.reduce((sum, d) => sum + (d.day >= root.today || isNaN(d.forecast) ? 0 : d.forecast), 0) + root.todayForecastSoFar
    readonly property real remaining: root.days.reduce((sum, d) => sum + (d.day <= root.today || isNaN(d.forecast) ? 0 : d.forecast), 0) + root.todayRemaining
    readonly property var bestDay: root.days.reduce((best, d) => !isNaN(d.energy) && (!best || d.energy > best.energy) ? d : best, null)
    readonly property real highest: Math.max(0, ...root.days.map(d => isNaN(d.energy) ? 0 : d.energy), ...root.days.map(d => isNaN(d.forecast) ? 0 : d.forecast))

    function dayName(day: real): string {
        return Qt.locale().dayName(new Date(day).getDay(), Locale.ShortFormat);
    }

    spacing: 16

    GridLayout {
        Layout.fillWidth: true
        columns: root.width > 560 ? 4 : 2
        columnSpacing: 16
        rowSpacing: 12

        EnergyStat {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            label: qsTr("Produced this week")
            value: EnergyFormat.energy(root.produced)
            detail: root.forecastSoFar > 100 ? qsTr("%1 % of forecast so far").arg(Math.round(100 * root.produced / root.forecastSoFar)) : ""
            color: root.color
        }
        EnergyStat {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            label: qsTr("Best day")
            value: root.bestDay ? EnergyFormat.energy(root.bestDay.energy) : "–"
            detail: root.bestDay ? Qt.locale().dayName(new Date(root.bestDay.day).getDay(), Locale.LongFormat) : ""
        }
        EnergyStat {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            label: qsTr("Still expected")
            value: EnergyFormat.energy(root.remaining)
        }
        EnergyStat {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            label: qsTr("Expected this week")
            value: EnergyFormat.energy(root.produced + root.remaining)
        }
    }

    EnergyChartView {
        id: chart
        Layout.fillWidth: true
        Layout.fillHeight: true

        // One category per day, for plotX().
        xMin: 0
        xMax: Math.max(1, root.days.length)

        // Charted in kWh.
        readonly property real yStep: chart.niceStep(root.highest / 1000)

        // Behind today's bars.
        Rectangle {
            visible: root.todayIndex >= 0
            x: chart.plotX(root.todayIndex)
            y: chart.plotArea.y
            width: chart.plotArea.width / chart.xMax
            height: chart.plotArea.height
            color: Qt.rgba(root.Material.foreground.r, root.Material.foreground.g, root.Material.foreground.b, 0.06)
        }

        BarCategoryAxis {
            id: dayAxis
            categories: root.days.map(d => d.day === root.today ? qsTr("Today") : root.dayName(d.day))
            lineVisible: false
            gridVisible: false
            labelsColor: chart.axisTextColor
            labelsFont.pixelSize: 11
        }
        EnergyValueAxis {
            id: energyY
            textColor: chart.axisTextColor
            min: 0
            max: Math.max(1, Math.ceil(root.highest / 1000 / chart.yStep)) * chart.yStep
            tickCount: Math.round(energyY.max / chart.yStep) + 1
            labelFormat: chart.yStep < 1 ? "%.1f kWh" : "%.0f kWh"
        }

        BarSeries {
            axisX: dayAxis
            axisY: energyY
            barWidth: 0.8

            BarSet {
                label: qsTr("Produced")
                color: root.color
                borderColor: "transparent"
                values: root.days.map(d => isNaN(d.energy) ? 0 : d.energy / 1000)
            }
            BarSet {
                label: qsTr("Forecast")
                color: Qt.rgba(root.Material.hintTextColor.r, root.Material.hintTextColor.g, root.Material.hintTextColor.b, 0.35)
                borderColor: root.Material.hintTextColor
                values: root.days.map(d => isNaN(d.forecast) ? 0 : d.forecast / 1000)
            }
        }
    }
}
