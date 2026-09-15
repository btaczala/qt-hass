pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtCharts

import QtHomeAssistant

// A numeric sensor's value over 24 hours, like the graph in Lovelace's
// more-info, in HistoryPanel's windows. The line is the 5-minute mean with a
// band from its minimum to maximum.
//
// Sensors with a state_class come from recorder statistics (5-minute
// statistics are kept for 10 days by default), which stay a few hundred
// points however often the sensor reports. Others, or ones without
// statistics yet, come from state history, averaged into the same 5-minute
// buckets.
HistoryPanel {
    id: root

    readonly property real bucketMs: 5 * 60000
    readonly property color lineColor: root.Material.accentColor

    // [{x, mean, min, max}] with x in ms since the epoch.
    function finish(request: int, points: var) {
        // The live value ends the last 24 hours, since statistics lag behind.
        if (root.offsetDays === 0 && !isNaN(root.entity.value))
            points.push({
                x: root.windowEnd,
                mean: root.entity.value,
                min: root.entity.value,
                max: root.entity.value
            });
        root.done(request, points);
    }

    function fetchStatistics(request: int) {
        const sent = HassAPI.command("recorder/statistics_during_period", {
            start_time: new Date(root.windowStart).toISOString(),
            end_time: new Date(root.windowEnd).toISOString(),
            statistic_ids: [root.entityId],
            period: "5minute",
            types: ["mean", "min", "max", "state"]
        }, root, (ok, json, message) => {
            if (request !== root.request)
                return;
            if (!ok) {
                root.failed(request, message);
                return;
            }
            const rows = JSON.parse(json)[root.entityId] ?? [];
            // Not recorded as statistics (yet): the states themselves.
            if (rows.length === 0) {
                root.fetchHistory(request);
                return;
            }
            // Total sensors have no mean, only each period's last state.
            root.finish(request, rows.map(row => {
                const mean = row.mean ?? row.state;
                return {
                    x: (row.start + row.end) / 2,
                    mean: mean,
                    min: row.min ?? mean,
                    max: row.max ?? mean
                };
            }).filter(point => point.mean !== null && point.mean !== undefined));
        });
        if (!sent)
            root.failed(request, qsTr("Not connected"));
    }

    function fetchHistory(request: int) {
        root.history(request, states => {
            // In time order, keyed by 5-minute bucket.
            const buckets = new Map();
            for (const entry of states) {
                const value = Number(entry.s);
                if (entry.s === "" || isNaN(value))
                    continue;
                // The first state is the one at the window's start, changed
                // before it.
                const time = Math.max(entry.lu * 1000, root.windowStart);
                const key = Math.floor((time - root.windowStart) / root.bucketMs);
                const bucket = buckets.get(key);
                if (bucket) {
                    bucket.sum += value;
                    bucket.count += 1;
                    bucket.min = Math.min(bucket.min, value);
                    bucket.max = Math.max(bucket.max, value);
                    bucket.last = value;
                } else {
                    buckets.set(key, {
                        x: time,
                        sum: value,
                        count: 1,
                        min: value,
                        max: value,
                        last: value
                    });
                }
            }
            // As steps: a state holds until the next change.
            const hold = (x, value) => ({
                    x: x,
                    mean: value,
                    min: value,
                    max: value
                });
            const points = [];
            let held = null;
            for (const bucket of buckets.values()) {
                if (held !== null)
                    points.push(hold(bucket.x, held));
                points.push({
                    x: bucket.x,
                    mean: bucket.sum / bucket.count,
                    min: bucket.min,
                    max: bucket.max
                });
                held = bucket.last;
            }
            if (held !== null)
                points.push(hold(root.windowEnd, held));
            root.finish(request, points);
        });
    }

    function fill() {
        meanSeries.clear();
        minSeries.clear();
        maxSeries.clear();
        if (root.points.length === 0) {
            valueAxis.min = 0;
            valueAxis.max = 1;
            return;
        }
        let low = Infinity;
        let high = -Infinity;
        for (const point of root.points) {
            meanSeries.append(point.x, point.mean);
            minSeries.append(point.x, point.min);
            maxSeries.append(point.x, point.max);
            low = Math.min(low, point.min);
            high = Math.max(high, point.max);
        }
        // Round limits a step beyond the data; a flat line gets a unit around it.
        if (high - low < 1e-9) {
            low -= 1;
            high += 1;
        }
        const step = chart.niceStep(high - low);
        valueAxis.min = Math.floor(low / step) * step;
        valueAxis.max = Math.ceil(high / step) * step;
        valueAxis.tickCount = Math.round((valueAxis.max - valueAxis.min) / step) + 1;
        const decimals = step < 1 ? Math.ceil(-Math.log10(step) - 1e-9) : 0;
        valueAxis.labelFormat = `%.${decimals}f`;
    }

    unit: root.entity.attributes.unit_of_measurement ?? ""

    onLoadRequested: request => {
        const stateClass = root.entity.attributes.state_class ?? "";
        if (["measurement", "total", "total_increasing"].includes(stateClass))
            root.fetchStatistics(request);
        else
            root.fetchHistory(request);
    }
    onPointsChanged: root.fill()

    EnergyChartView {
        id: chart
        Layout.fillWidth: true
        Layout.preferredHeight: 220
        legend.visible: false
        xMin: root.windowStart
        xMax: root.windowEnd

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
        EnergyValueAxis {
            id: valueAxis
            textColor: chart.axisTextColor
        }

        AreaSeries {
            axisX: timeAxis
            axisY: valueAxis
            color: Qt.alpha(root.lineColor, 0.25)
            borderColor: "transparent"
            borderWidth: 0
            upperSeries: LineSeries {
                id: maxSeries
            }
            lowerSeries: LineSeries {
                id: minSeries
            }
        }
        LineSeries {
            id: meanSeries
            axisX: timeAxis
            axisY: valueAxis
            color: root.lineColor
            width: 2
        }

        Label {
            anchors.centerIn: parent
            visible: root.placeholder !== ""
            text: root.placeholder
            color: root.Material.hintTextColor
        }
    }
}
