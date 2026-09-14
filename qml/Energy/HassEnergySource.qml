pragma ComponentBehavior: Bound

import QtQml
import QtQuick

import QtHomeAssistant

// Home Assistant data for the energy page, in the shape EnergyFlowCard and the
// detail overlays take: live readings in W/Wh (grid positive while importing,
// battery positive while discharging), and chart series as [{x, y}] with x in
// local hours -- since today's midnight for today's series, since the epoch
// (`absoluteHour`) for the week of SoC history.
//
// Which entities to read is up to the user (see the list at the top of
// PageEnergy.qml); what each has to provide is documented on its property.
// Anything historical comes from recorder statistics, so those entities need a
// state_class. Only exists while connected (the dashboard does), so statistics
// are fetched on creation and then refreshed on a timer.
Item {
    id: root

    // Power sensors (W or kW). Grid positive while importing, battery positive
    // while discharging. Solar and home also need statistics (mean).
    required property string solarPowerEntity
    required property string gridPowerEntity
    required property string batteryPowerEntity
    required property string homePowerEntity
    // Individually metered consumers, each a power sensor with statistics
    // (mean): [{name, icon, entity, and optionally insideOf -- the entity of
    // a consumer whose reading already includes this one's}].
    required property var consumerEntities
    // Battery: state of charge and its low limit (%), capacity (Wh or kWh).
    // SoC also needs statistics (mean).
    required property string batterySocEntity
    required property string batteryMinSocEntity
    required property string batteryCapacityEntity
    // Energy since midnight (Wh or kWh).
    required property string solarEnergyTodayEntity
    required property string homeEnergyTodayEntity
    // Ever-increasing energy totals (Wh or kWh), used through statistics
    // (sum): grid import and export, and home consumption.
    required property string gridImportTotalEntity
    required property string gridExportTotalEntity
    required property string homeEnergyTotalEntity
    // Solcast's forecast for today, read from its `detailedForecast`
    // attribute.
    required property string solarForecastEntity
    // Pstryk's current buy and sell price, read from their `All prices`
    // attribute; the unit (e.g. PLN/kWh) gives the currency.
    required property string buyPriceEntity
    required property string sellPriceEntity

    // W the battery can charge at, for the chance of a full charge today.
    required property real batteryMaxPower

    // Clock, ticking often enough for the charts' "now" marker.
    property real now: Date.now()
    readonly property real midnight: new Date(root.now).setHours(0, 0, 0, 0)
    readonly property real hour: (root.now - root.midnight) / 3600000
    readonly property real absoluteHour: root.absoluteHourOf(root.now)

    readonly property real solarPower: root.orZero(solar.baseValue)
    readonly property real gridPower: root.orZero(grid.baseValue)
    readonly property real batteryPower: root.orZero(battery.baseValue)
    readonly property real batterySoc: root.orZero(soc.value)
    readonly property real batteryCapacity: isNaN(capacity.baseValue) ? 10000 : capacity.baseValue
    readonly property real batteryMinSoc: isNaN(minSoc.value) ? 10 : minSoc.value
    readonly property real solarEnergy: root.orZero(solarToday.baseValue)
    readonly property real homePower: root.orZero(home.baseValue)
    readonly property real homeEnergy: root.orZero(homeToday.baseValue)

    readonly property string currency: (buyPrice.attributes.unit_of_measurement ?? "").split("/")[0]

    // Solcast's 30-minute forecast (average kW over each period), at period
    // midpoints, in W: the estimate and its 10th/90th percentiles.
    readonly property var solarForecast: root.forecastSeries("pv_estimate")
    readonly property var solarForecastLow: root.forecastSeries("pv_estimate10")
    readonly property var solarForecastHigh: root.forecastSeries("pv_estimate90")
    // 5-minute averages so far today, then the live reading.
    readonly property var solarActual: root.solarStats.concat([{
                x: root.hour,
                y: root.solarPower
            }])
    readonly property var homeActual: root.homeStats.concat([{
                x: root.hour,
                y: root.homePower
            }])
    // consumerEntities, each with its live `power` (W), today's `points`
    // (5-minute averages, then the live reading) and `energy` so far today
    // (Wh, from those averages).
    readonly property var consumers: {
        const result = [];
        for (let i = 0; i < consumerReadings.count; ++i) {
            const entry = root.consumerEntities[i];
            const reading = consumerReadings.objectAt(i) as HassEntity;
            if (!entry || !reading)
                continue;
            const stats = root.consumerStats[entry.entity] ?? [];
            const power = root.orZero(reading.baseValue);
            result.push({
                name: entry.name,
                icon: entry.icon,
                entity: entry.entity,
                insideOf: entry.insideOf ?? "",
                power: power,
                points: stats.concat([{
                        x: root.hour,
                        y: power
                    }]),
                energy: stats.reduce((sum, p) => sum + p.y * 5 / 60, 0)
            });
        }
        return result;
    }
    readonly property var importPrices: root.priceSeries(buyPrice.attributes["All prices"])
    readonly property var exportPrices: root.priceSeries(sellPrice.attributes["All prices"])
    // Hourly SoC means over the last week, then the live reading.
    readonly property var socHistory: root.socStats.concat([{
                x: root.absoluteHour,
                y: root.batterySoc
            }])
    // Average home consumption per hour of the day over the last week, in W.
    property var loadProfile: []

    // Since midnight, from 5-minute statistics: Wh, and money at each hour's
    // price.
    property real importedEnergy: 0
    property real exportedEnergy: 0
    readonly property real importCost: root.costOf(root.importSteps, root.importPrices)
    readonly property real exportRevenue: root.costOf(root.exportSteps, root.exportPrices)

    property var solarStats: []
    property var homeStats: []
    // Today's 5-minute averages per consumer entity.
    property var consumerStats: ({})
    property var socStats: []
    property var importSteps: []
    property var exportSteps: []

    function orZero(value: real): real {
        return isNaN(value) ? 0 : value;
    }

    // Local hours since the epoch, so floor(x / 24) is a local calendar day.
    function absoluteHourOf(ms: real): real {
        return (ms - new Date(ms).getTimezoneOffset() * 60000) / 3600000;
    }

    // Hours since today's midnight for an ISO date-time. One without an offset
    // is local time; parsed by hand, as JS engines disagree on that form.
    function hourOf(iso: string): real {
        const m = /^(\d+)-(\d+)-(\d+)T(\d+):(\d+)(?::(\d+))?$/.exec(iso);
        const ms = m ? new Date(+m[1], m[2] - 1, +m[3], +m[4], +m[5], +(m[6] ?? 0)).getTime() : Date.parse(iso);
        return (ms - root.midnight) / 3600000;
    }

    function forecastSeries(field: string): var {
        const periods = forecast.attributes.detailedForecast ?? [];
        return periods.map(p => ({
                    x: root.hourOf(p.period_start) + 0.25,
                    y: p[field] * 1000
                }));
    }

    function priceSeries(prices: var): var {
        return (prices ?? []).map(p => ({
                    x: root.hourOf(p.start),
                    y: p.price
                })).filter(p => p.x >= 0 && p.x < 24);
    }

    // Money for [{x: hour, y: Wh}] steps at the price of the hour each is in.
    function costOf(steps: var, prices: var): real {
        let total = 0;
        for (const s of steps) {
            const price = prices.find(p => s.x >= p.x && s.x < p.x + 1);
            if (price)
                total += s.y / 1000 * price.y;
        }
        return total;
    }

    function statistics(ids: var, start: real, period: string, types: var, done: var) {
        HassAPI.command("recorder/statistics_during_period", {
            start_time: new Date(start).toISOString(),
            statistic_ids: ids,
            period: period,
            types: types,
            // Converted by HA, so values don't depend on each sensor's unit.
            units: {
                power: "W",
                energy: "Wh"
            }
        }, root, (ok, json) => {
            if (ok)
                done(JSON.parse(json));
        });
    }

    function refreshToday() {
        const consumerIds = root.consumerEntities.map(c => c.entity);
        root.statistics([root.solarPowerEntity, root.homePowerEntity].concat(consumerIds), root.midnight, "5minute", ["mean"], result => {
            // Plotted at the middle of each 5 minutes.
            const means = id => (result[id] ?? []).filter(r => r.mean !== null).map(r => ({
                        x: (r.start - root.midnight) / 3600000 + 2.5 / 60,
                        y: r.mean
                    }));
            root.solarStats = means(root.solarPowerEntity);
            root.homeStats = means(root.homePowerEntity);
            const stats = {};
            for (const id of consumerIds)
                stats[id] = means(id);
            root.consumerStats = stats;
        });
        root.statistics([root.gridImportTotalEntity, root.gridExportTotalEntity], root.midnight, "5minute", ["change"], result => {
            const steps = id => (result[id] ?? []).map(r => ({
                        x: (r.start - root.midnight) / 3600000,
                        y: r.change ?? 0
                    }));
            root.importSteps = steps(root.gridImportTotalEntity);
            root.exportSteps = steps(root.gridExportTotalEntity);
            root.importedEnergy = root.importSteps.reduce((sum, s) => sum + s.y, 0);
            root.exportedEnergy = root.exportSteps.reduce((sum, s) => sum + s.y, 0);
        });
    }

    function refreshWeek() {
        const weekAgo = root.now - 7 * 24 * 3600000;
        root.statistics([root.batterySocEntity], weekAgo, "hour", ["mean"], result => {
            root.socStats = (result[root.batterySocEntity] ?? []).filter(r => r.mean !== null).map(r => ({
                        x: root.absoluteHourOf(r.start) + 0.5,
                        y: r.mean
                    }));
        });
        root.statistics([root.homeEnergyTotalEntity], weekAgo, "hour", ["change"], result => {
            const sums = new Array(24).fill(0);
            const counts = new Array(24).fill(0);
            for (const r of result[root.homeEnergyTotalEntity] ?? []) {
                if (r.change === null)
                    continue;
                const h = new Date(r.start).getHours();
                sums[h] += r.change;
                counts[h] += 1;
            }
            root.loadProfile = sums.map((sum, h) => ({
                        x: h,
                        y: counts[h] ? sum / counts[h] : 0
                    }));
        });
    }

    HassEntity {
        id: solar
        entityId: root.solarPowerEntity
    }
    HassEntity {
        id: grid
        entityId: root.gridPowerEntity
    }
    HassEntity {
        id: battery
        entityId: root.batteryPowerEntity
    }
    HassEntity {
        id: soc
        entityId: root.batterySocEntity
    }
    HassEntity {
        id: capacity
        entityId: root.batteryCapacityEntity
    }
    HassEntity {
        id: minSoc
        entityId: root.batteryMinSocEntity
    }
    HassEntity {
        id: solarToday
        entityId: root.solarEnergyTodayEntity
    }
    Instantiator {
        id: consumerReadings
        model: root.consumerEntities

        delegate: HassEntity {
            required property var modelData
            entityId: modelData.entity
        }
    }
    HassEntity {
        id: home
        entityId: root.homePowerEntity
    }
    HassEntity {
        id: homeToday
        entityId: root.homeEnergyTodayEntity
    }
    HassEntity {
        id: forecast
        entityId: root.solarForecastEntity
    }
    HassEntity {
        id: buyPrice
        entityId: root.buyPriceEntity
    }
    HassEntity {
        id: sellPrice
        entityId: root.sellPriceEntity
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }
    // Five-minute statistics are compiled every five minutes; hourly ones
    // hourly, so refreshing those every 15 minutes catches each new hour soon.
    Timer {
        interval: 5 * 60000
        running: true
        repeat: true
        onTriggered: root.refreshToday()
    }
    Timer {
        interval: 15 * 60000
        running: true
        repeat: true
        onTriggered: root.refreshWeek()
    }
    // Today's series restart at midnight.
    onMidnightChanged: root.refreshToday()

    Component.onCompleted: {
        root.refreshToday();
        root.refreshWeek();
    }
}
