import QtQuick
import QtQuick.Controls.Material
import QtCharts

// A ChartView styled for the energy detail overlays: see-through, Material
// text colors, legend on top, and an optional "now" marker. Declare axes
// (EnergyValueAxis) and series inside it and fill line series with
// setPoints(); items declared inside it can be placed with plotX().
ChartView {
    id: root

    // The x range across the plot area that the "now" marker and plotX() use
    // -- the x axis's range, or 0..24 for hourly bars -- and where "now" is;
    // NaN hides the marker.
    property real xMin: 0
    property real xMax: 24
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
    // Only changed points are touched, so a series that just grows at the end
    // stays cheap to update. replace() matches points by value, which is safe
    // because x only ever increases along a series.
    function setPoints(series: LineSeries, points: var, scale: real) {
        const shared = Math.min(series.count, points.length);
        for (let i = 0; i < shared; ++i) {
            const old = series.at(i);
            const y = points[i].y * scale;
            if (old.x !== points[i].x || old.y !== y)
                series.replace(old.x, old.y, points[i].x, y);
        }
        if (series.count > points.length)
            series.removePoints(points.length, series.count - points.length);
        for (let i = shared; i < points.length; ++i)
            series.append(points[i].x, points[i].y * scale);
    }

    // Plot-area x for `value` on the xMin..xMax range.
    function plotX(value: real): real {
        return root.plotArea.x + root.plotArea.width * (value - root.xMin) / (root.xMax - root.xMin);
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
        visible: !isNaN(root.nowX) && root.nowX >= root.xMin && root.nowX <= root.xMax
        x: root.plotX(root.nowX)
        y: root.plotArea.y
        width: 1
        height: root.plotArea.height
        color: root.Material.accentColor
    }
}
