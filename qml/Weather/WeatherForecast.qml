pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

import QtHomeAssistant

// Daily forecast as columns, after weather-chart-card: day and condition on
// top, then a chart of highs (a line colored by temperature) and lows (dotted)
// over precipitation bars, then precipitation amounts and wind.
Item {
    id: root

    // HA forecast entries: {datetime, condition, temperature, templow,
    // precipitation, wind_speed, wind_bearing}.
    property var forecast: []
    property string precipitationUnit: "mm"
    property string windSpeedUnit: "m/s"
    property real chartHeight: 150

    readonly property int count: root.forecast.length
    readonly property real columnWidth: root.count > 0 ? root.width / root.count : 0
    readonly property var highs: root.forecast.map(f => f.temperature)
    readonly property var lows: root.forecast.map(f => f.templow ?? NaN)
    readonly property real maxTemp: Math.max(...root.highs, ...root.lows.filter(t => !isNaN(t)))
    readonly property real minTemp: Math.min(...root.highs, ...root.lows.filter(t => !isNaN(t)))
    // Scale for the bars: at least 10 mm tall, so a drizzle stays small.
    readonly property real maxPrecipitation: Math.max(10, ...root.forecast.map(f => f.precipitation ?? 0))

    // Room above the highest high and below the lowest low for their labels.
    readonly property real chartTop: 22
    readonly property real chartBottom: root.chartHeight - 22

    readonly property color gridColor: root.Material.dividerColor

    function columnX(index: int): real {
        return root.columnWidth * (index + 0.5);
    }

    function temperatureY(t: real): real {
        const span = root.maxTemp - root.minTemp;
        return span > 0 ? root.chartTop + (root.maxTemp - t) / span * (root.chartBottom - root.chartTop) : (root.chartTop + root.chartBottom) / 2;
    }

    // Blue when freezing through green and yellow to red when hot.
    function temperatureColor(t: real): color {
        const stops = [[-10, "#5c6bc0"], [0, "#42a5f5"], [8, "#26c6da"], [14, "#9ccc65"], [20, "#ffee58"], [26, "#ffa726"], [32, "#ef5350"]];
        if (t <= stops[0][0])
            return stops[0][1];
        for (let i = 1; i < stops.length; ++i) {
            if (t <= stops[i][0]) {
                const f = (t - stops[i - 1][0]) / (stops[i][0] - stops[i - 1][0]);
                return Qt.tint(stops[i - 1][1], Qt.alpha(stops[i][1], f));
            }
        }
        return stops[stops.length - 1][1];
    }

    function formatTemperature(t: real): string {
        return isNaN(t) ? "" : Number(t).toLocaleString(Qt.locale(), "f", 1) + "°";
    }

    implicitHeight: days.height + chart.height + bottomRow.height + 8

    // Day name and condition icon per column.
    Row {
        id: days

        Repeater {
            model: root.forecast

            delegate: Column {
                id: day
                required property var modelData
                width: root.columnWidth
                spacing: 4

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: new Date(day.modelData.datetime).toLocaleDateString(Qt.locale(), "ddd")
                    font.bold: true
                }
                WeatherIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    condition: day.modelData.condition
                    size: 30
                }
            }
        }
    }

    Item {
        id: chart
        y: days.height + 4
        width: root.width
        height: root.chartHeight

        // Drawn once per data or size change, not animated.
        Canvas {
            id: canvas
            anchors.fill: parent

            onPaint: {
                const ctx = canvas.getContext("2d");
                ctx.reset();
                const n = root.count;
                if (n === 0)
                    return;
                const grid = root.gridColor;

                ctx.lineWidth = 1;
                ctx.strokeStyle = Qt.rgba(grid.r, grid.g, grid.b, 0.5 * grid.a);
                ctx.setLineDash([3, 3]);
                for (let i = 0; i < n; ++i) {
                    ctx.beginPath();
                    ctx.moveTo(Math.round(root.columnX(i)) + 0.5, 0);
                    ctx.lineTo(Math.round(root.columnX(i)) + 0.5, canvas.height);
                    ctx.stroke();
                }
                ctx.setLineDash([]);
                ctx.strokeStyle = grid;
                ctx.beginPath();
                ctx.moveTo(0, canvas.height - 0.5);
                ctx.lineTo(canvas.width, canvas.height - 0.5);
                ctx.stroke();

                // Precipitation, up from the bottom to at most 40 % of the height.
                ctx.fillStyle = "rgba(30, 136, 229, 0.55)";
                const barWidth = Math.min(28, root.columnWidth * 0.45);
                for (let i = 0; i < n; ++i) {
                    const mm = root.forecast[i].precipitation ?? 0;
                    if (mm <= 0)
                        continue;
                    const h = Math.max(2, mm / root.maxPrecipitation * canvas.height * 0.4);
                    ctx.fillRect(root.columnX(i) - barWidth / 2, canvas.height - h, barWidth, h);
                }

                // A smooth line through column centers.
                const curve = values => {
                    ctx.beginPath();
                    let previous = null;
                    for (let i = 0; i < n; ++i) {
                        if (isNaN(values[i]))
                            continue;
                        const x = root.columnX(i);
                        const y = root.temperatureY(values[i]);
                        if (!previous) {
                            ctx.moveTo(x, y);
                        } else {
                            const dx = (x - previous.x) / 2;
                            ctx.bezierCurveTo(previous.x + dx, previous.y, x - dx, y, x, y);
                        }
                        previous = {
                            x: x,
                            y: y
                        };
                    }
                    ctx.stroke();
                };
                const dots = (values, colorOf) => {
                    for (let i = 0; i < n; ++i) {
                        if (isNaN(values[i]))
                            continue;
                        ctx.fillStyle = colorOf(values[i]);
                        ctx.beginPath();
                        ctx.arc(root.columnX(i), root.temperatureY(values[i]), 3.5, 0, 2 * Math.PI);
                        ctx.fill();
                    }
                };

                const low = "#42a5f5";
                ctx.lineWidth = 3;
                ctx.strokeStyle = low;
                ctx.setLineDash([1, 2.5]);
                ctx.lineCap = "round";
                curve(root.lows);
                ctx.setLineDash([]);
                dots(root.lows, () => low);

                const gradient = ctx.createLinearGradient(root.columnX(0), 0, root.columnX(n - 1), 0);
                for (let i = 0; i < n; ++i)
                    gradient.addColorStop(n > 1 ? i / (n - 1) : 0, root.temperatureColor(root.highs[i]).toString());
                ctx.strokeStyle = gradient;
                curve(root.highs);
                dots(root.highs, t => root.temperatureColor(t).toString());
            }
        }

        Repeater {
            model: root.count

            delegate: Item {
                id: labels
                required property int index
                readonly property real high: root.highs[labels.index] ?? NaN
                readonly property real low: root.lows[labels.index] ?? NaN

                Label {
                    x: root.columnX(labels.index) - width / 2
                    y: root.temperatureY(labels.high) - height - 4
                    text: root.formatTemperature(labels.high)
                    font.pixelSize: 12
                    font.bold: true
                }
                Label {
                    x: root.columnX(labels.index) - width / 2
                    y: root.temperatureY(labels.low) + 5
                    visible: !isNaN(labels.low)
                    text: root.formatTemperature(labels.low)
                    font.pixelSize: 12
                    color: root.Material.secondaryTextColor
                }
            }
        }
    }

    // Precipitation amount and wind per column.
    Row {
        id: bottomRow
        y: chart.y + chart.height + 4

        Repeater {
            model: root.forecast

            delegate: Column {
                id: column
                required property var modelData
                width: root.columnWidth
                spacing: 4

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    // Keeps the row's height when there's nothing to show.
                    opacity: (column.modelData.precipitation ?? 0) > 0 ? 1 : 0
                    text: Number(column.modelData.precipitation ?? 0).toLocaleString(Qt.locale(), "f", 1) + " " + root.precipitationUnit
                    font.pixelSize: 12
                    font.bold: true
                }
                WindIndicator {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: column.modelData.wind_speed !== undefined
                    speed: column.modelData.wind_speed ?? 0
                    bearing: column.modelData.wind_bearing ?? NaN
                    unit: root.windSpeedUnit
                }
            }
        }
    }

    onForecastChanged: canvas.requestPaint()
    onGridColorChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onChartHeightChanged: canvas.requestPaint()
}
