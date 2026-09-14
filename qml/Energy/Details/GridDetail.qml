pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtCharts

import QtHomeAssistant

import "EnergyFormat.js" as EnergyFormat

// Grid overlay: current flow and prices, today's energy and money both ways,
// the best hours still ahead to import and to export, and today's hourly
// prices as bars with those hours highlighted.
ColumnLayout {
    id: root

    // W, positive while importing.
    property real power: 0
    // [{x: hour, y: price per kWh}], each for the hour starting at x.
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

    // How many of the remaining hours count as the best ones.
    property int bestHourCount: 3

    function priceAt(prices: var, hour: real): var {
        return prices.find(p => hour >= p.x && hour < p.x + 1) ?? null;
    }

    // Prices by hour of the day, 0 where missing, for the bar sets.
    function hourly(prices: var): var {
        const values = new Array(24).fill(0);
        for (const p of prices)
            if (p.x >= 0 && p.x < 24)
                values[Math.floor(p.x)] = p.y;
        return values;
    }

    // The bestHourCount hours from the current one on with the lowest
    // (`sign` -1) or highest (1) price, as [{x, y}] in time order.
    function bestHours(prices: var, sign: int): var {
        return prices.filter(p => p.x + 1 > root.nowHour).sort((a, b) => sign * (b.y - a.y)).slice(0, root.bestHourCount).sort((a, b) => a.x - b.x);
    }

    // Consecutive hours merged into ranges: [{from, to, average}].
    function ranges(hours: var): var {
        const result = [];
        for (const h of hours) {
            const last = result[result.length - 1];
            if (last && last.to === h.x) {
                last.average = (last.average * (last.to - last.from) + h.y) / (last.to - last.from + 1);
                last.to += 1;
            } else {
                result.push({
                    from: h.x,
                    to: h.x + 1,
                    average: h.y
                });
            }
        }
        return result;
    }

    readonly property var importNow: root.priceAt(root.importPrices, root.nowHour)
    readonly property var exportNow: root.priceAt(root.exportPrices, root.nowHour)
    readonly property var bestImportHours: root.bestHours(root.importPrices, -1)
    readonly property var bestExportHours: root.bestHours(root.exportPrices, 1)

    // A price range as a small tinted pill, e.g. "13:00–15:00 · 1.11".
    component TimeChip: Rectangle {
        id: chip

        property var range
        property color tint

        implicitWidth: chipLabel.implicitWidth + 16
        implicitHeight: chipLabel.implicitHeight + 8
        radius: height / 2
        color: Qt.rgba(chip.tint.r, chip.tint.g, chip.tint.b, 0.2)
        border.width: 1
        border.color: chip.tint

        Label {
            id: chipLabel
            anchors.centerIn: parent
            text: qsTr("%1–%2 · %3").arg(EnergyFormat.clock(chip.range.from)).arg(EnergyFormat.clock(chip.range.to)).arg(chip.range.average.toFixed(2))
            font.pixelSize: 12
        }
    }

    // A caption and the chips for one direction's best hours.
    component BestTimes: RowLayout {
        id: best

        property string label
        property var hours: []
        property color tint

        spacing: 8

        Label {
            Layout.preferredWidth: 130
            text: best.label
            font.pixelSize: 13
            color: root.Material.secondaryTextColor
            elide: Text.ElideRight
        }
        Flow {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.ranges(best.hours)

                delegate: TimeChip {
                    required property var modelData
                    range: modelData
                    tint: best.tint
                }
            }
            Label {
                visible: best.hours.length === 0
                text: qsTr("No hours left today")
                font.pixelSize: 12
                color: root.Material.hintTextColor
            }
        }
    }

    spacing: 12

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
        EnergyStat {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            label: qsTr("Net cost today")
            value: EnergyFormat.money(root.importCost - root.exportRevenue, root.currency)
        }
    }

    BestTimes {
        Layout.fillWidth: true
        label: qsTr("Cheapest to import")
        hours: root.bestImportHours
        tint: root.importColor
    }
    BestTimes {
        Layout.fillWidth: true
        label: qsTr("Best to export")
        hours: root.bestExportHours
        tint: root.exportColor
    }

    EnergyChartView {
        id: chart
        Layout.fillWidth: true
        Layout.fillHeight: true

        xMin: 0
        xMax: 24
        nowX: root.nowHour

        readonly property real lowest: Math.min(0, ...root.importPrices.map(p => p.y), ...root.exportPrices.map(p => p.y))
        readonly property real highest: Math.max(0, ...root.importPrices.map(p => p.y), ...root.exportPrices.map(p => p.y))
        readonly property real yStep: chart.niceStep(chart.highest - chart.lowest)

        BarCategoryAxis {
            id: hourAxis
            categories: Array.from({
                length: 24
            }, (_, h) => String(h))
            lineVisible: false
            gridVisible: false
            labelsColor: chart.axisTextColor
            labelsFont.pixelSize: 10
        }
        EnergyValueAxis {
            id: priceY
            textColor: chart.axisTextColor
            min: Math.floor(chart.lowest / chart.yStep + 1e-9) * chart.yStep
            max: Math.max(priceY.min + chart.yStep, Math.ceil(chart.highest / chart.yStep - 1e-9) * chart.yStep)
            tickCount: Math.round((priceY.max - priceY.min) / chart.yStep) + 1
            labelFormat: "%.2f"
        }

        BarSeries {
            axisX: hourAxis
            axisY: priceY
            barWidth: 0.8

            BarSet {
                label: qsTr("Import price (%1/kWh)").arg(root.currency)
                color: root.importColor
                borderColor: "transparent"
                values: root.hourly(root.importPrices)
            }
            BarSet {
                label: qsTr("Export price (%1/kWh)").arg(root.currency)
                color: root.exportColor
                borderColor: "transparent"
                values: root.hourly(root.exportPrices)
            }
        }

        // Bands over the best hours ahead, faint since they draw over the
        // bars: import on the plot's lower half, export on its upper half, so
        // an hour that's both stays readable.
        Repeater {
            model: root.bestImportHours

            delegate: Rectangle {
                required property var modelData
                x: chart.plotX(modelData.x)
                y: chart.plotArea.y + chart.plotArea.height / 2
                width: chart.plotArea.width / 24
                height: chart.plotArea.height / 2
                color: Qt.rgba(root.importColor.r, root.importColor.g, root.importColor.b, 0.18)
            }
        }
        Repeater {
            model: root.bestExportHours

            delegate: Rectangle {
                required property var modelData
                x: chart.plotX(modelData.x)
                y: chart.plotArea.y
                width: chart.plotArea.width / 24
                height: chart.plotArea.height / 2
                color: Qt.rgba(root.exportColor.r, root.exportColor.g, root.exportColor.b, 0.18)
            }
        }
    }
}
