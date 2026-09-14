pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtCharts

import QtHomeAssistant

import "EnergyFormat.js" as EnergyFormat

// Home overlay: consumption now and today, where it's coming from, every
// individually metered consumer's share of it, and today's consumption charted
// with the biggest consumers'.
ColumnLayout {
    id: root

    // W, as drawn on the flow diagram, and split by source.
    property real power: 0
    property real fromSolar: 0
    property real fromBattery: 0
    property real fromGrid: 0
    // Wh since midnight: used by the home, and imported from the grid.
    property real energyToday: 0
    property real importedToday: 0
    // [{x: hour, y: W}] so far today.
    property var actual: []
    // Individually metered consumers: [{name, icon, entity, insideOf (entity
    // of the consumer this one's reading is part of, or ""), power (W),
    // points ([{x: hour, y: W}] so far today), energy (Wh today)}].
    property var consumers: []
    property real nowHour: 0
    // How many of the biggest consumers today get a line on the chart.
    property int chartedConsumers: 5

    property color color: Material.accentColor
    property color solarColor: "#ff9800"
    property color batteryColor: "#4db6ac"
    property color gridColor: "#488fc2"
    // Consumer colors, assigned in the order consumers are listed.
    property var consumerColors: ["#9ccc65", "#64b5f6", "#ffb74d", "#e57373", "#ba68c8", "#4dd0e1", "#f06292", "#fff176", "#a1887f", "#7986cb", "#4db6ac", "#ff8a65", "#90a4ae", "#dce775", "#ce93d8"]

    function colorOf(index: int): color {
        return root.consumerColors[index % root.consumerColors.length];
    }

    // Consumers with their color, largest power first, each followed by the
    // consumers inside it (`nested`).
    readonly property var rows: {
        const all = root.consumers.map((c, i) => Object.assign({
                color: root.colorOf(i),
                nested: c.insideOf !== ""
            }, c));
        const byPower = (a, b) => b.power - a.power || a.name.localeCompare(b.name);
        const result = [];
        for (const top of all.filter(c => !c.nested).sort(byPower)) {
            result.push(top);
            result.push(...all.filter(c => c.insideOf === top.entity).sort(byPower));
        }
        // Nested under a consumer that isn't listed: show at the end.
        result.push(...all.filter(c => c.nested && !all.some(p => p.entity === c.insideOf)));
        return result;
    }
    // Nested consumers are already part of the one they're inside.
    readonly property real consumersPower: root.rows.filter(c => !c.nested).reduce((sum, c) => sum + Math.max(0, c.power), 0)
    readonly property var charted: root.rows.slice().sort((a, b) => b.energy - a.energy).slice(0, root.chartedConsumers)
    readonly property real peak: {
        let peak = Math.max(0, ...root.actual.map(p => p.y));
        for (const c of root.charted)
            peak = Math.max(peak, ...c.points.map(p => p.y));
        return peak;
    }

    // A consumer's row: icon, name, a bar of its share of the home's power,
    // its power now and its energy today.
    component ConsumerRow: RowLayout {
        id: row

        property string name
        property string icon
        property color color
        property real watts
        property real wattHours: NaN
        property bool nested

        spacing: 10

        MdiIcon {
            Layout.leftMargin: row.nested ? 24 : 0
            icon: row.icon
            iconSize: 20
            color: row.color
        }
        Label {
            Layout.preferredWidth: row.nested ? 136 : 160
            text: row.name
            elide: Text.ElideRight
        }
        Item {
            Layout.fillWidth: true
            implicitHeight: 8

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Qt.rgba(root.Material.foreground.r, root.Material.foreground.g, root.Material.foreground.b, 0.1)
            }
            Rectangle {
                width: parent.width * (root.power > 0 ? Math.min(1, Math.max(0, row.watts) / root.power) : 0)
                height: parent.height
                radius: height / 2
                color: row.color
            }
        }
        Label {
            Layout.preferredWidth: 64
            horizontalAlignment: Text.AlignRight
            text: EnergyFormat.power(row.watts)
        }
        Label {
            Layout.preferredWidth: 64
            horizontalAlignment: Text.AlignRight
            text: isNaN(row.wattHours) ? "" : EnergyFormat.energy(row.wattHours)
            font.pixelSize: 12
            color: root.Material.hintTextColor
        }
    }

    spacing: 10

    GridLayout {
        Layout.fillWidth: true
        columns: root.width > 560 ? 3 : 2
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
            label: qsTr("Used today")
            value: EnergyFormat.energy(root.energyToday)
        }
        // HA's energy dashboard definition: the share of consumption not
        // bought from the grid.
        EnergyStat {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            label: qsTr("Self-sufficiency today")
            value: root.energyToday > 0 ? Math.round(100 * Math.max(0, 1 - root.importedToday / root.energyToday)) + " %" : "—"
        }
    }

    // Where the power is coming from right now, in the flow diagram's colors.
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        Row {
            id: sourceBar
            Layout.fillWidth: true

            readonly property real total: Math.max(1, root.fromSolar + root.fromBattery + root.fromGrid)

            Repeater {
                model: [
                    {
                        watts: root.fromSolar,
                        color: root.solarColor
                    },
                    {
                        watts: root.fromBattery,
                        color: root.batteryColor
                    },
                    {
                        watts: root.fromGrid,
                        color: root.gridColor
                    }
                ]

                delegate: Rectangle {
                    required property var modelData
                    width: sourceBar.width * modelData.watts / sourceBar.total
                    height: 10
                    color: modelData.color
                }
            }
        }
        Label {
            text: qsTr("Now from solar %1 % · battery %2 % · grid %3 %").arg(Math.round(100 * root.fromSolar / sourceBar.total)).arg(Math.round(100 * root.fromBattery / sourceBar.total)).arg(Math.round(100 * root.fromGrid / sourceBar.total))
            font.pixelSize: 12
            color: root.Material.secondaryTextColor
        }
    }

    // Scrolls once there are more consumers than fit; the chart gets the rest.
    Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(consumerColumn.implicitHeight, 7 * 30)
        contentHeight: consumerColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {}

        ColumnLayout {
            id: consumerColumn
            width: parent.width - 12
            spacing: 6

            // By index rather than over the array itself, so the rows update
            // in place instead of being recreated on every reading.
            Repeater {
                model: root.rows.length

                delegate: ConsumerRow {
                    id: consumerRow
                    required property int index
                    readonly property var entry: root.rows[consumerRow.index]
                    Layout.fillWidth: true
                    name: consumerRow.entry.name
                    icon: consumerRow.entry.icon
                    color: consumerRow.entry.color
                    watts: consumerRow.entry.power
                    wattHours: consumerRow.entry.energy
                    nested: consumerRow.entry.nested
                }
            }
            ConsumerRow {
                Layout.fillWidth: true
                name: qsTr("Rest of home")
                icon: "mdi:home"
                color: root.color
                watts: Math.max(0, root.power - root.consumersPower)
            }
        }
    }

    EnergyChartView {
        id: chart
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 160

        xMin: 0
        xMax: 24
        nowX: root.nowHour

        // Charted in kW.
        readonly property real yStep: chart.niceStep(root.peak / 1000)
        // One line per charted consumer slot, created on first update; each
        // slot shows whichever consumer is at that rank.
        property var consumerSeries: []
        // Set once created: the change handlers below can fire while this is
        // still being built, before consumerSeries has its initial value,
        // which would then overwrite the series created by that early call.
        property bool ready: false

        function update() {
            const all = chart.consumerSeries.slice();
            for (let i = all.length; i < root.chartedConsumers; ++i) {
                const series = chart.createSeries(ChartView.SeriesTypeLine, "", homeX, homeY);
                series.width = 2;
                all.push(series);
            }
            chart.consumerSeries = all;
            chart.setPoints(homeSeries, root.actual, 0.001);
            for (let i = 0; i < all.length; ++i) {
                const consumer = root.charted[i];
                all[i].visible = consumer !== undefined;
                if (!consumer)
                    continue;
                if (all[i].name !== consumer.name) {
                    all[i].name = consumer.name;
                    all[i].color = consumer.color;
                }
                chart.setPoints(all[i], consumer.points, 0.001);
            }
        }

        EnergyValueAxis {
            id: homeX
            textColor: chart.axisTextColor
            min: 0
            max: 24
            tickType: ValueAxis.TicksDynamic
            tickAnchor: 0
            tickInterval: 3
            labelFormat: "%02.0f:00"
        }
        EnergyValueAxis {
            id: homeY
            textColor: chart.axisTextColor
            min: 0
            max: Math.max(1, Math.ceil(root.peak / 1000 / chart.yStep)) * chart.yStep
            tickCount: Math.round(homeY.max / chart.yStep) + 1
            labelFormat: chart.yStep < 1 ? "%.1f kW" : "%.0f kW"
        }

        AreaSeries {
            name: qsTr("Home")
            axisX: homeX
            axisY: homeY
            color: Qt.rgba(root.color.r, root.color.g, root.color.b, 0.3)
            borderColor: root.color
            borderWidth: 2
            upperSeries: LineSeries {
                id: homeSeries
            }
        }
    }

    onActualChanged: if (chart.ready)
        chart.update()
    onChartedChanged: if (chart.ready)
        chart.update()
    Component.onCompleted: {
        chart.ready = true;
        chart.update();
    }
}
