import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtCharts

import QtHomeAssistant

import "EnergyFormat.js" as EnergyFormat

// Solar overlay: production now and today, and today's actual production
// charted against the forecast.
ColumnLayout {
    id: root

    property real power: 0
    // Wh produced since midnight.
    property real producedEnergy: 0
    // [{x: hour, y: W}], evenly spaced, covering the whole day.
    property var forecast: []
    // [{x: hour, y: W}] so far today.
    property var actual: []
    property real nowHour: 0
    property color color: "#ff9800"

    // Wh under the forecast curve between two hours (trapezoids).
    function forecastEnergy(from: real, to: real): real {
        let sum = 0;
        for (let i = 1; i < root.forecast.length; ++i) {
            const a = root.forecast[i - 1];
            const b = root.forecast[i];
            const lo = Math.max(from, a.x);
            const hi = Math.min(to, b.x);
            if (hi <= lo)
                continue;
            const yAt = x => a.y + (b.y - a.y) * (x - a.x) / (b.x - a.x);
            sum += (yAt(lo) + yAt(hi)) / 2 * (hi - lo);
        }
        return sum;
    }

    readonly property real forecastTotal: root.forecastEnergy(0, 24)
    readonly property real forecastSoFar: root.forecastEnergy(0, root.nowHour)
    readonly property real forecastRemaining: Math.max(0, root.forecastTotal - root.forecastSoFar)
    readonly property real peak: Math.max(...root.forecast.map(p => p.y), ...root.actual.map(p => p.y), 0)

    // Chart range: daylight hours per the forecast, with an hour either side.
    readonly property real firstLight: {
        const p = root.forecast.find(p => p.y > 0);
        return p ? Math.max(0, Math.floor(p.x) - 1) : 0;
    }
    readonly property real lastLight: {
        for (let i = root.forecast.length - 1; i >= 0; --i)
            if (root.forecast[i].y > 0)
                return Math.min(24, Math.ceil(root.forecast[i].x) + 1);
        return 24;
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
            label: qsTr("Now")
            value: EnergyFormat.power(root.power)
            color: root.color
        }
        EnergyStat {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            label: qsTr("Produced today")
            value: EnergyFormat.energy(root.producedEnergy)
            detail: root.forecastSoFar > 100 ? qsTr("%1 % of forecast so far").arg(Math.round(100 * root.producedEnergy / root.forecastSoFar)) : ""
        }
        EnergyStat {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            label: qsTr("Forecast today")
            value: EnergyFormat.energy(root.forecastTotal)
        }
        EnergyStat {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            label: qsTr("Still expected")
            value: EnergyFormat.energy(root.forecastRemaining)
        }
    }

    EnergyChartView {
        id: chart
        Layout.fillWidth: true
        Layout.fillHeight: true

        markerAxis: solarX
        nowX: root.nowHour

        // Charted in kW.
        readonly property real yStep: chart.niceStep(root.peak / 1000)

        EnergyValueAxis {
            id: solarX
            textColor: chart.axisTextColor
            min: root.firstLight
            max: root.lastLight
            tickType: ValueAxis.TicksDynamic
            tickAnchor: 0
            tickInterval: root.lastLight - root.firstLight > 12 ? 3 : 2
            labelFormat: "%02.0f:00"
        }
        EnergyValueAxis {
            id: solarY
            textColor: chart.axisTextColor
            min: 0
            max: Math.max(1, Math.ceil(root.peak / 1000 / chart.yStep)) * chart.yStep
            tickCount: Math.round(solarY.max / chart.yStep) + 1
            labelFormat: chart.yStep < 1 ? "%.1f kW" : "%.0f kW"
        }

        LineSeries {
            id: forecastSeries
            name: qsTr("Forecast")
            axisX: solarX
            axisY: solarY
            color: root.Material.hintTextColor
            width: 1.5
            style: Qt.DashLine
        }
        AreaSeries {
            name: qsTr("Actual")
            axisX: solarX
            axisY: solarY
            color: Qt.rgba(root.color.r, root.color.g, root.color.b, 0.3)
            borderColor: root.color
            borderWidth: 2
            upperSeries: LineSeries {
                id: actualSeries
            }
        }
    }

    onForecastChanged: chart.setPoints(forecastSeries, root.forecast, false, 0.001)
    onActualChanged: chart.setPoints(actualSeries, root.actual, false, 0.001)
    Component.onCompleted: {
        chart.setPoints(forecastSeries, root.forecast, false, 0.001);
        chart.setPoints(actualSeries, root.actual, false, 0.001);
    }
}
