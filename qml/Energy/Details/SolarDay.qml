import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtCharts

import QtHomeAssistant

import "EnergyFormat.js" as EnergyFormat

// One day of solar production, for SolarDetail's tabs: the day's figures, a
// bar of its production against the forecast, and its production charted
// (against the forecast curve, when there is one). `live` is today, still
// going: production now, what's still expected and a "now" marker; otherwise
// it's a finished day, with its peak instead.
ColumnLayout {
    id: root

    property bool live: true
    property real power: 0
    // Wh produced that day (so far).
    property real producedEnergy: 0
    // [{x: hour, y: W}], evenly spaced, covering the whole day; may be empty.
    property var forecast: []
    // [{x: hour, y: W}] that day (so far).
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

    // Wh; from the curve unless set, NaN when unknown.
    property real forecastTotal: root.forecast.length > 0 ? root.forecastEnergy(0, 24) : NaN
    readonly property bool hasForecast: !isNaN(root.forecastTotal)
    readonly property real forecastSoFar: !root.hasForecast ? 0 : root.live ? root.forecastEnergy(0, root.nowHour) : root.forecastTotal
    readonly property real forecastRemaining: root.live ? Math.max(0, root.forecastTotal - root.forecastSoFar) : 0
    readonly property real peak: Math.max(...root.forecast.map(p => p.y), ...root.actual.map(p => p.y), 0)
    // The day's highest production reading.
    readonly property var actualPeak: root.actual.reduce((best, p) => !best || p.y > best.y ? p : best, null)

    // Chart range: daylight hours per the forecast (or, without one, the
    // production), with an hour either side.
    readonly property var daylight: {
        const points = root.forecast.some(p => p.y > 0) ? root.forecast : root.actual;
        const lit = points.filter(p => p.y > 10);
        return lit.length ? lit : null;
    }
    readonly property real firstLight: root.daylight ? Math.max(0, Math.floor(root.daylight[0].x) - 1) : 0
    readonly property real lastLight: root.daylight ? Math.min(24, Math.ceil(root.daylight[root.daylight.length - 1].x) + 1) : 24

    spacing: 16

    GridLayout {
        Layout.fillWidth: true
        columns: root.width > 560 ? 4 : 2
        columnSpacing: 16
        rowSpacing: 12

        EnergyStat {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            label: root.live ? qsTr("Now") : qsTr("Peak")
            value: root.live ? EnergyFormat.power(root.power) : root.actualPeak ? EnergyFormat.power(root.actualPeak.y) : "–"
            detail: !root.live && root.actualPeak ? qsTr("at %1").arg(EnergyFormat.clock(root.actualPeak.x)) : ""
            color: root.color
        }
        EnergyStat {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            label: root.live ? qsTr("Produced today") : qsTr("Produced")
            value: EnergyFormat.energy(root.producedEnergy)
            detail: root.forecastSoFar > 100 ? (root.live ? qsTr("%1 % of forecast so far") : qsTr("%1 % of forecast")).arg(Math.round(100 * root.producedEnergy / root.forecastSoFar)) : ""
        }
        EnergyStat {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            label: root.live ? qsTr("Forecast today") : qsTr("Forecast")
            value: root.hasForecast ? EnergyFormat.energy(root.forecastTotal) : "–"
        }
        EnergyStat {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            label: root.live ? qsTr("Still expected") : !root.hasForecast ? qsTr("Against forecast") : root.producedEnergy >= root.forecastTotal ? qsTr("Above forecast") : qsTr("Below forecast")
            value: root.live ? EnergyFormat.energy(root.forecastRemaining) : root.hasForecast ? EnergyFormat.energy(Math.abs(root.producedEnergy - root.forecastTotal)) : "–"
        }
    }

    // The day's production on a scale of its forecast: what's produced so
    // far, in a red-orange-green gradient spanning the whole bar (so the
    // color at its end shows how far along the forecast the day is), then
    // what's still expected, and a tick where the forecast says production
    // should be by now (at the end of a finished day: the forecast itself).
    Item {
        id: progress
        Layout.fillWidth: true
        implicitHeight: 14

        readonly property real total: Math.max(1, root.hasForecast ? root.forecastTotal : 0, root.producedEnergy + root.forecastRemaining)
        readonly property real producedFraction: Math.min(1, root.producedEnergy / progress.total)
        readonly property real expectedFraction: Math.min(1 - progress.producedFraction, root.forecastRemaining / progress.total)
        readonly property color trackColor: Qt.rgba(root.Material.foreground.r, root.Material.foreground.g, root.Material.foreground.b, 0.1)

        Accessible.role: Accessible.ProgressBar
        Accessible.name: qsTr("Produced %1 of %2 forecast, %3 still expected").arg(EnergyFormat.energy(root.producedEnergy)).arg(root.hasForecast ? EnergyFormat.energy(root.forecastTotal) : "–").arg(EnergyFormat.energy(root.forecastRemaining))

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: progress.trackColor
        }
        // Starts under the produced part's end, so its rounded left edge
        // doesn't show.
        Rectangle {
            x: Math.max(0, progress.width * progress.producedFraction - progress.height)
            width: progress.width * (progress.producedFraction + progress.expectedFraction) - x
            height: progress.height
            radius: height / 2
            visible: progress.expectedFraction > 0
            color: progress.trackColor
            border.width: 1
            border.color: Qt.rgba(root.Material.foreground.r, root.Material.foreground.g, root.Material.foreground.b, 0.25)
        }
        Item {
            width: progress.width * progress.producedFraction
            height: progress.height
            clip: true

            Rectangle {
                width: progress.width
                height: progress.height
                radius: height / 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: "#e53935"
                    }
                    GradientStop {
                        position: 0.5
                        color: "#fb8c00"
                    }
                    GradientStop {
                        position: 1
                        color: "#43a047"
                    }
                }
            }
        }
        Rectangle {
            visible: root.forecastSoFar > 0
            x: progress.width * Math.min(1, root.forecastSoFar / progress.total) - width / 2
            y: -3
            width: 2
            height: progress.height + 6
            color: root.Material.foreground
        }
    }

    EnergyChartView {
        id: chart
        Layout.fillWidth: true
        Layout.fillHeight: true

        xMin: solarX.min
        xMax: solarX.max
        nowX: root.live ? root.nowHour : NaN

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
            visible: root.forecast.length > 0
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

    onForecastChanged: chart.setPoints(forecastSeries, root.forecast, 0.001)
    onActualChanged: chart.setPoints(actualSeries, root.actual, 0.001)
    Component.onCompleted: {
        chart.setPoints(forecastSeries, root.forecast, 0.001);
        chart.setPoints(actualSeries, root.actual, 0.001);
    }
}
