import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtCharts

import QtHomeAssistant

import "EnergyFormat.js" as EnergyFormat

// Grid overlay: current flow and prices, today's energy and money both ways,
// and today's import and export prices charted by hour.
ColumnLayout {
    id: root

    // W, positive while importing.
    property real power: 0
    // [{x: hour, y: price per kWh}], each holding until the next point.
    property var importPrices: []
    property var exportPrices: []
    property string currency
    property real nowHour: 0
    // Since midnight: Wh, and money in `currency`.
    property real importedEnergy: 0
    property real exportedEnergy: 0
    property real importCost: 0
    property real exportRevenue: 0
    property color importColor: "#488fc2"
    property color exportColor: "#8353d1"

    function priceAt(prices: var, hour: real): var {
        let current = null;
        for (const p of prices)
            if (p.x <= hour)
                current = p;
        return current;
    }
    // The cheapest or dearest price entry, `sign` 1 for dearest.
    function extreme(prices: var, sign: int): var {
        let best = null;
        for (const p of prices)
            if (!best || sign * p.y > sign * best.y)
                best = p;
        return best;
    }
    function slot(p: var): string {
        return p ? qsTr("%1–%2").arg(EnergyFormat.clock(p.x)).arg(EnergyFormat.clock(p.x + 1)) : "";
    }

    readonly property var importNow: root.priceAt(root.importPrices, root.nowHour)
    readonly property var exportNow: root.priceAt(root.exportPrices, root.nowHour)
    readonly property var cheapestImport: root.extreme(root.importPrices, -1)
    readonly property var bestExport: root.extreme(root.exportPrices, 1)

    spacing: 16

    GridLayout {
        Layout.fillWidth: true
        columns: root.width > 560 ? 4 : 2
        columnSpacing: 16
        rowSpacing: 12

        EnergyStat {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            label: root.power >= 0 ? qsTr("Importing now") : qsTr("Exporting now")
            value: EnergyFormat.power(root.power)
            color: root.power >= 0 ? root.importColor : root.exportColor
            detail: root.importNow && root.exportNow ? qsTr("Buy %1 · sell %2").arg(root.importNow.y.toFixed(2)).arg(root.exportNow.y.toFixed(2)) : ""
        }
        EnergyStat {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            label: qsTr("Cheapest import")
            value: root.cheapestImport ? EnergyFormat.price(root.cheapestImport.y, root.currency) : "—"
            detail: root.slot(root.cheapestImport)
        }
        EnergyStat {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            label: qsTr("Imported today")
            value: EnergyFormat.energy(root.importedEnergy)
            detail: qsTr("Cost %1").arg(EnergyFormat.money(root.importCost, root.currency))
            color: root.importColor
        }
        EnergyStat {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            label: qsTr("Exported today")
            value: EnergyFormat.energy(root.exportedEnergy)
            detail: qsTr("Earned %1").arg(EnergyFormat.money(root.exportRevenue, root.currency))
            color: root.exportColor
        }
    }

    Label {
        Layout.fillWidth: true
        text: root.bestExport ? qsTr("Best time to export: %1 at %2. Net cost today: %3.").arg(root.slot(root.bestExport)).arg(EnergyFormat.price(root.bestExport.y, root.currency)).arg(EnergyFormat.money(root.importCost - root.exportRevenue, root.currency)) : ""
        wrapMode: Text.WordWrap
        font.pixelSize: 13
        color: root.Material.secondaryTextColor
    }

    EnergyChartView {
        id: chart
        Layout.fillWidth: true
        Layout.fillHeight: true

        markerAxis: priceX
        nowX: root.nowHour

        readonly property real lowest: Math.min(0, ...root.importPrices.map(p => p.y), ...root.exportPrices.map(p => p.y))
        readonly property real highest: Math.max(0, ...root.importPrices.map(p => p.y), ...root.exportPrices.map(p => p.y))
        readonly property real yStep: chart.niceStep(chart.highest - chart.lowest)

        EnergyValueAxis {
            id: priceX
            textColor: chart.axisTextColor
            min: 0
            max: 24
            tickType: ValueAxis.TicksDynamic
            tickAnchor: 0
            tickInterval: 3
            labelFormat: "%02.0f:00"
        }
        EnergyValueAxis {
            id: priceY
            textColor: chart.axisTextColor
            min: Math.floor(chart.lowest / chart.yStep + 1e-9) * chart.yStep
            max: Math.max(priceY.min + chart.yStep, Math.ceil(chart.highest / chart.yStep - 1e-9) * chart.yStep)
            tickCount: Math.round((priceY.max - priceY.min) / chart.yStep) + 1
            labelFormat: "%.2f"
        }

        AreaSeries {
            name: qsTr("Import price (%1/kWh)").arg(root.currency)
            axisX: priceX
            axisY: priceY
            color: Qt.rgba(root.importColor.r, root.importColor.g, root.importColor.b, 0.2)
            borderColor: root.importColor
            borderWidth: 2
            upperSeries: LineSeries {
                id: importSeries
            }
        }
        LineSeries {
            id: exportSeries
            name: qsTr("Export price (%1/kWh)").arg(root.currency)
            axisX: priceX
            axisY: priceY
            color: root.exportColor
            width: 2
        }
    }

    onImportPricesChanged: chart.setPoints(importSeries, root.importPrices, true, 1)
    onExportPricesChanged: chart.setPoints(exportSeries, root.exportPrices, true, 1)
    Component.onCompleted: {
        chart.setPoints(importSeries, root.importPrices, true, 1);
        chart.setPoints(exportSeries, root.exportPrices, true, 1);
    }
}
