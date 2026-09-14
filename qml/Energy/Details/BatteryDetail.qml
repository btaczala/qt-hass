import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtCharts

import QtHomeAssistant

import "EnergyFormat.js" as EnergyFormat

// Battery overlay: charge level, when it'll be full or down to its reserve,
// how likely it is to reach full today, and the last week of SoC.
ColumnLayout {
    id: root

    property real soc: 0
    // W, positive while discharging.
    property real power: 0
    property real capacity: 10000 // Wh
    property real maxPower: 2500
    // SoC the battery stops discharging at.
    property real minSoc: 10
    property real nowHour: 0
    // Hours since some fixed midnight, on the same axis as `history`.
    property real absoluteHour: 0
    // [{x: absolute hour, y: SoC}] over the last week.
    property var history: []
    // Today's solar forecast [{x: hour, y: W}], evenly spaced, and typical
    // home consumption [{x: hour, y: W}], one point per hour.
    property var solarForecast: []
    property var loadProfile: []
    property color chargeColor: "#f06292"
    property color dischargeColor: "#4db6ac"

    // Below this the battery counts as idle and has no ETA.
    readonly property real idleThreshold: 10
    readonly property bool charging: root.power <= -root.idleThreshold
    readonly property bool discharging: root.power >= root.idleThreshold

    // Hours until full or down to the reserve at the current rate, or -1.
    readonly property real etaHours: {
        if (root.charging)
            return (100 - root.soc) / 100 * root.capacity / -root.power;
        if (root.discharging)
            return Math.max(0, root.soc - root.minSoc) / 100 * root.capacity / root.power;
        return -1;
    }

    // Solar left over after the home's typical consumption for the rest of
    // today, as much as the battery can take per interval, in Wh.
    readonly property real expectedSurplus: {
        if (root.solarForecast.length < 2)
            return 0;
        const interval = root.solarForecast[1].x - root.solarForecast[0].x;
        let sum = 0;
        for (const p of root.solarForecast) {
            if (p.x < root.nowHour)
                continue;
            const load = root.loadProfile[Math.min(root.loadProfile.length - 1, Math.floor(p.x))];
            sum += Math.min(root.maxPower, Math.max(0, p.y - (load ? load.y : 0))) * interval;
        }
        return sum;
    }
    readonly property real energyToFull: (100 - root.soc) / 100 * root.capacity

    // Chance of reaching full today: the expected surplus is taken to be off
    // by a normally distributed error of 30 % (a typical day-ahead solar
    // forecast miss), and this is the probability it still covers what's
    // missing.
    readonly property real fullProbability: {
        if (root.soc >= 99)
            return 1;
        if (root.expectedSurplus <= 0)
            return 0;
        const z = (root.expectedSurplus - root.energyToFull) / (0.3 * root.expectedSurplus);
        return root.normalCdf(z);
    }

    // Abramowitz & Stegun 7.1.26.
    function normalCdf(z: real): real {
        const x = Math.abs(z) / Math.SQRT2;
        const t = 1 / (1 + 0.3275911 * x);
        const erf = 1 - ((((1.061405429 * t - 1.453152027) * t + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * Math.exp(-x * x);
        return z >= 0 ? (1 + erf) / 2 : (1 - erf) / 2;
    }

    readonly property var weekStats: {
        const h = root.history;
        if (h.length === 0)
            return null;
        let sum = 0;
        let min = 100;
        let charged = 0;
        const fullDays = new Set();
        for (let i = 0; i < h.length; ++i) {
            sum += h[i].y;
            min = Math.min(min, h[i].y);
            if (h[i].y >= 99)
                fullDays.add(Math.floor(h[i].x / 24));
            if (i > 0)
                charged += Math.max(0, h[i].y - h[i - 1].y);
        }
        const days = Math.max(1, (h[h.length - 1].x - h[0].x) / 24);
        return {
            average: sum / h.length,
            min: min,
            fullDays: fullDays.size,
            cyclesPerDay: charged / 100 / days
        };
    }

    readonly property int today: Math.floor(root.absoluteHour / 24)

    // Labels the last week's days on the chart: short weekday names, counted
    // back from today's real weekday.
    function fillDayAxis() {
        for (const label of [...dayAxis.categoriesLabels])
            dayAxis.remove(label);
        const weekday = new Date().getDay();
        for (let d = root.today - 7; d <= root.today; ++d) {
            const label = d === root.today ? qsTr("Today") : Qt.locale().dayName((weekday + (d - root.today) % 7 + 7) % 7, Locale.ShortFormat);
            dayAxis.append(label, (d + 1) * 24);
        }
    }

    readonly property color stateColor: root.charging ? root.chargeColor : root.discharging ? root.dischargeColor : root.Material.foreground

    spacing: 12

    RowLayout {
        Layout.fillWidth: true
        spacing: 24

        // Battery gauge: a body filled up to the SoC, and a terminal cap.
        Row {
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                width: 120
                height: 56
                radius: 8
                color: "transparent"
                border.width: 2
                border.color: root.Material.secondaryTextColor

                Rectangle {
                    x: 5
                    y: 5
                    height: parent.height - 10
                    width: (parent.width - 10) * Math.max(0, Math.min(100, root.soc)) / 100
                    radius: 4
                    color: root.soc <= root.minSoc ? root.Material.color(Material.Red) : root.charging ? root.chargeColor : root.dischargeColor

                    Behavior on width {
                        NumberAnimation {
                            duration: 300
                        }
                    }
                }
                Label {
                    anchors.centerIn: parent
                    text: Math.round(root.soc) + " %"
                    font.pixelSize: 22
                    font.bold: true
                    style: Text.Outline
                    styleColor: root.Material.background
                }
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 6
                height: 20
                radius: 2
                color: root.Material.secondaryTextColor
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: root.width > 560 ? 3 : 1
            columnSpacing: 16
            rowSpacing: 8

            EnergyStat {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                label: root.charging ? qsTr("Charging") : root.discharging ? qsTr("Discharging") : qsTr("Idle")
                value: EnergyFormat.power(root.power)
                color: root.stateColor
                detail: qsTr("%1 of %2").arg(EnergyFormat.energy(root.soc / 100 * root.capacity)).arg(EnergyFormat.energy(root.capacity))
            }
            EnergyStat {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                label: root.charging ? qsTr("Full at") : root.discharging ? qsTr("Reserve (%1 %) at").arg(root.minSoc) : qsTr("Estimated time")
                value: root.etaHours < 0 ? "—" : root.etaHours === 0 ? qsTr("Now") : EnergyFormat.clock(root.nowHour + root.etaHours)
                detail: root.etaHours > 0 ? qsTr("in %1 at this rate").arg(EnergyFormat.duration(root.etaHours)) : ""
            }
            EnergyStat {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                label: qsTr("Full charge today")
                value: Math.round(100 * root.fullProbability) + " %"
                detail: root.soc >= 99 ? qsTr("Already full") : qsTr("Spare %1 / needs %2").arg(EnergyFormat.energy(root.expectedSurplus)).arg(EnergyFormat.energy(root.energyToFull))
            }
        }
    }

    MenuSeparator {
        Layout.fillWidth: true
        topPadding: 0
        bottomPadding: 0
    }

    Label {
        text: qsTr("Last 7 days")
        font.pixelSize: 15
    }

    GridLayout {
        Layout.fillWidth: true
        columns: root.width > 560 ? 4 : 2
        columnSpacing: 16
        rowSpacing: 8
        visible: root.weekStats !== null

        EnergyStat {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            label: qsTr("Average level")
            value: root.weekStats ? Math.round(root.weekStats.average) + " %" : ""
        }
        EnergyStat {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            label: qsTr("Lowest level")
            value: root.weekStats ? Math.round(root.weekStats.min) + " %" : ""
        }
        EnergyStat {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            label: qsTr("Days fully charged")
            value: root.weekStats ? qsTr("%1 of 7").arg(Math.min(7, root.weekStats.fullDays)) : ""
        }
        EnergyStat {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            label: qsTr("Cycles per day")
            value: root.weekStats ? root.weekStats.cyclesPerDay.toFixed(2) : ""
        }
    }

    EnergyChartView {
        id: chart
        Layout.fillWidth: true
        Layout.fillHeight: true

        // One category per calendar day, labelled at its middle, so the grid
        // lines fall on midnights.
        CategoryAxis {
            id: dayAxis
            min: root.absoluteHour - 7 * 24
            max: root.absoluteHour
            startValue: (root.today - 7) * 24
            labelsPosition: CategoryAxis.AxisLabelsPositionCenter
            lineVisible: false
            labelsColor: chart.axisTextColor
            labelsFont.pixelSize: 11
            gridLineColor: Qt.rgba(chart.axisTextColor.r, chart.axisTextColor.g, chart.axisTextColor.b, 0.15)
        }
        EnergyValueAxis {
            id: socAxis
            textColor: chart.axisTextColor
            min: 0
            max: 100
            tickCount: 5
            labelFormat: "%.0f %"
        }

        AreaSeries {
            name: qsTr("State of charge")
            axisX: dayAxis
            axisY: socAxis
            color: Qt.rgba(root.dischargeColor.r, root.dischargeColor.g, root.dischargeColor.b, 0.3)
            borderColor: root.dischargeColor
            borderWidth: 2
            upperSeries: LineSeries {
                id: socSeries
            }
        }
    }

    // History drops old points from the front as it grows, which setPoints
    // would see as every point changing; rebuilding is no dearer.
    onHistoryChanged: {
        socSeries.clear();
        chart.setPoints(socSeries, root.history, false, 1);
    }
    onTodayChanged: root.fillDayAxis()
    Component.onCompleted: {
        root.fillDayAxis();
        chart.setPoints(socSeries, root.history, false, 1);
    }
}
