import QtQuick
import QtQuick.Controls.Material
import QtCharts

// A ChartView styled for the energy detail overlays: see-through, Material
// text colors, legend on top, and an optional "now" marker. Declare axes
// (EnergyValueAxis) and series inside it and fill the series with setPoints().
ChartView {
    id: root

    // The x axis the "now" marker is placed along, and where; NaN hides it.
    property ValueAxis markerAxis
    property real nowX: NaN

    readonly property color axisTextColor: root.Material.hintTextColor

    // A round step (1, 2, 2.5 or 5 times a power of ten) splitting `range`
    // into about four intervals.
    function niceStep(range: real): real {
        const raw = Math.max(range, 1e-6) / 4;
        const magnitude = Math.pow(10, Math.floor(Math.log10(raw)));
        for (const f of [1, 2, 2.5, 5])
            if (f * magnitude >= raw)
                return f * magnitude;
        return 10 * magnitude;
    }

    // Makes `series` show `points` ([{x, y}]), with y multiplied by `scale`.
    // With `step`, each y holds until the next point's x (the last one for as
    // long as the spacing before it). Only changed points are touched, so a
    // series that just grows at the end stays cheap to update -- except step
    // series, which are rebuilt on any change: their doubled-up points aren't
    // unique, and replace() matches points by value.
    function setPoints(series: LineSeries, points: var, step: bool, scale: real) {
        const target = [];
        for (let i = 0; i < points.length; ++i) {
            const y = points[i].y * scale;
            target.push(Qt.point(points[i].x, y));
            if (step) {
                const spacing = i > 0 ? points[i].x - points[i - 1].x : 1;
                target.push(Qt.point(i + 1 < points.length ? points[i + 1].x : points[i].x + spacing, y));
            }
        }

        let shared = Math.min(series.count, target.length);
        if (step) {
            for (let i = 0; i < shared; ++i) {
                const old = series.at(i);
                if (old.x !== target[i].x || old.y !== target[i].y) {
                    shared = 0;
                    break;
                }
            }
        } else {
            for (let i = 0; i < shared; ++i) {
                const old = series.at(i);
                if (old.x !== target[i].x || old.y !== target[i].y)
                    series.replace(old.x, old.y, target[i].x, target[i].y);
            }
        }
        if (series.count > shared)
            series.removePoints(shared, series.count - shared);
        for (let i = shared; i < target.length; ++i)
            series.append(target[i].x, target[i].y);
    }

    backgroundColor: "transparent"
    plotAreaColor: "transparent"
    antialiasing: true
    margins.top: 0
    margins.bottom: 0
    margins.left: 0
    margins.right: 0
    legend.alignment: Qt.AlignTop
    legend.labelColor: root.Material.secondaryTextColor
    legend.font.pixelSize: 12

    Rectangle {
        visible: root.markerAxis !== null && !isNaN(root.nowX) && root.nowX >= root.markerAxis.min && root.nowX <= root.markerAxis.max
        x: root.markerAxis ? root.plotArea.x + root.plotArea.width * (root.nowX - root.markerAxis.min) / (root.markerAxis.max - root.markerAxis.min) : 0
        y: root.plotArea.y
        width: 1
        height: root.plotArea.height
        color: root.Material.accentColor
    }
}
