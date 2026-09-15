pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtCharts

import QtHomeAssistant

// A binary sensor's history in HistoryPanel's windows, as a timeline: a bar of
// height 1 spanning each period the sensor was on, 0 while it was off (or
// unavailable). From state history, which for a binary sensor is only its
// changes.
HistoryPanel {
    id: root

    readonly property color barColor: root.Material.accentColor

    // The timeline as a step outline ([{x, y}], x in ms since the epoch),
    // starting and ending at 0; empty without any history.
    function outline(states: var): var {
        if (states.length === 0)
            return [];
        // The last 24 hours end now.
        const end = Math.min(root.windowEnd, Date.now());
        const points = [{
                x: root.windowStart,
                y: 0
            }];
        for (let i = 0; i < states.length; ++i) {
            if (states[i].s !== "on")
                continue;
            // The first state is the one at the window's start, changed before it.
            const from = Math.max(states[i].lu * 1000, root.windowStart);
            const to = Math.min(i + 1 < states.length ? states[i + 1].lu * 1000 : end, end);
            if (to <= from)
                continue;
            points.push({
                x: from,
                y: 0
            }, {
                x: from,
                y: 1
            }, {
                x: to,
                y: 1
            }, {
                x: to,
                y: 0
            });
        }
        points.push({
            x: end,
            y: 0
        });
        return points;
    }

    onLoadRequested: request => root.history(request, states => root.done(request, root.outline(states)))
    onPointsChanged: {
        onSeries.clear();
        for (const point of root.points)
            onSeries.append(point.x, point.y);
    }

    EnergyChartView {
        id: chart
        Layout.fillWidth: true
        Layout.preferredHeight: 120
        legend.visible: false

        DateTimeAxis {
            id: timeAxis
            min: new Date(root.windowStart)
            max: new Date(root.windowEnd)
            format: "HH:mm"
            tickCount: 5
            lineVisible: false
            labelsColor: chart.axisTextColor
            labelsFont.pixelSize: 11
            gridLineColor: Qt.rgba(chart.axisTextColor.r, chart.axisTextColor.g, chart.axisTextColor.b, 0.15)
        }
        // Just off and on, so no labels.
        EnergyValueAxis {
            id: stateAxis
            textColor: chart.axisTextColor
            min: 0
            max: 1
            tickCount: 2
            labelsVisible: false
        }

        AreaSeries {
            axisX: timeAxis
            axisY: stateAxis
            color: root.barColor
            borderColor: "transparent"
            borderWidth: 0
            upperSeries: LineSeries {
                id: onSeries
            }
        }

        Label {
            anchors.centerIn: parent
            visible: root.placeholder !== ""
            text: root.placeholder
            color: root.Material.hintTextColor
        }
    }
}
