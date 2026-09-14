import QtQuick
import QtCharts

// A value axis styled for EnergyChartView: no axis line, faint grid lines,
// small labels in `textColor` (pass the chart's axisTextColor).
ValueAxis {
    property color textColor

    lineVisible: false
    labelsColor: textColor
    labelsFont.pixelSize: 11
    gridLineColor: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.15)
    minorGridVisible: false
}
