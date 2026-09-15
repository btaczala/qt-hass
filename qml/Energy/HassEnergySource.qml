pragma ComponentBehavior: Bound

import QtQml
import QtQuick

import QtHomeAssistant

import "EnergyFlows.js" as EnergyFlows

// Home Assistant data for the energy page, in the shape EnergyFlowCard and the
// detail overlays take: live readings in W/Wh (grid positive while importing,
// battery positive while discharging), and chart series as [{x, y}] with x in
// local hours -- since that day's midnight for a day's series, since the epoch
// (`absoluteHour`) for the week of SoC history.
//
// Which entities to read is up to the user (EnergyFlowPage takes them as its
// own properties); what each has to provide is documented on its property.
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
    // (sum): grid import and export, battery charge and discharge, and home
    // consumption.
    required property string gridImportTotalEntity
    required property string gridExportTotalEntity
    required property string batteryChargeTotalEntity
    required property string batteryDischargeTotalEntity
    required property string homeEnergyTotalEntity
    // Solar production's lifetime total, for production per day and energy
    // by route today. Not the daily one (solarEnergyTodayEntity): its
    // statistics' change is garbage across the midnight reset (negative days).
    required property string solarEnergyTotalEntity
    // Solcast's forecast for today, read from its `detailedForecast`
    // attribute; its state (the day's total) is also read from history for
    // past days' forecasts, as the attribute isn't recorded.
    required property string solarForecastEntity
    // Solcast's forecast totals for the following days, from tomorrow on.
    required property var solarForecastDayEntities
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
    readonly property real yesterday: root.daysAfter(root.midnight, -1)
    // Midnight starting this week, per the locale's first day of the week.
    readonly property real weekStart: root.daysAfter(root.midnight, -((new Date(root.midnight).getDay() - Qt.locale().firstDayOfWeek + 7) % 7))

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
    // Yesterday's solar production: 5-minute averages ([{x: hour since
    // yesterday's midnight, y: W}]), total (Wh) and Solcast's final forecast
    // for it (Wh, NaN if unknown).
    property var solarYesterday: []
    readonly property real solarYesterdayEnergy: root.dailySolar[root.yesterday] ?? root.solarYesterday.reduce((sum, p) => sum + p.y * 5 / 60, 0)
    readonly property real solarYesterdayForecast: root.dailyForecast[root.yesterday] ?? NaN
    // This week, day by day: [{day: midnight in ms, energy: Wh produced (so
    // far today, NaN for days ahead), forecast: Wh (NaN if unknown)}].
    readonly property var solarWeek: {
        const days = [];
        for (let i = 0; i < 7; ++i) {
            const day = root.daysAfter(root.weekStart, i);
            let energy = NaN;
            let forecast = NaN;
            if (day < root.midnight) {
                energy = root.dailySolar[day] ?? NaN;
                forecast = root.dailyForecast[day] ?? NaN;
            } else if (day === root.midnight) {
                energy = root.solarEnergy;
                forecast = root.forecastTotal;
            } else {
                const index = Math.round((day - root.midnight) / 86400000) - 1;
                const ahead = index < forecastDays.count ? forecastDays.objectAt(index) as HassEntity : null;
                forecast = ahead ? ahead.baseValue : NaN;
            }
            days.push({
                day: day,
                energy: energy,
                forecast: forecast
            });
        }
        return days;
    }
    // Today's forecast total (Wh).
    readonly property real forecastTotal: forecast.baseValue
    // Wh produced per local day (keyed by midnight in ms), and Solcast's last
    // forecast for each, since the start of this week or yesterday.
    property var dailySolar: ({})
    property var dailyForecast: ({})

    // Average home consumption per hour of the day over the last week, in W.
    property var loadProfile: []

    // Since midnight, from 5-minute statistics: Wh, and money at each hour's
    // price.
    property real importedEnergy: 0
    property real exportedEnergy: 0
    // Wh since midnight by route, for EnergyFlowCard's energy mode: an
    // EnergyFlows.split() of each hour's totals, summed, so e.g. the battery
    // charging from the grid at night isn't credited to the day's solar.
    property var energyFlows: EnergyFlows.empty()
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

    // Midnight `days` days after the one at `day`; by date, not by 24 hours,
    // so it holds across a DST change.
    function daysAfter(day: real, days: int): real {
        const d = new Date(day);
        d.setDate(d.getDate() + days);
        return d.getTime();
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
        const totals = [root.solarEnergyTotalEntity, root.gridImportTotalEntity, root.gridExportTotalEntity, root.batteryChargeTotalEntity, root.batteryDischargeTotalEntity];
        root.statistics(totals, root.midnight, "5minute", ["change"], result => {
            const steps = id => (result[id] ?? []).map(r => ({
                        x: (r.start - root.midnight) / 3600000,
                        y: r.change ?? 0
                    }));
            root.importSteps = steps(root.gridImportTotalEntity);
            root.exportSteps = steps(root.gridExportTotalEntity);
            root.importedEnergy = root.importSteps.reduce((sum, s) => sum + s.y, 0);
            root.exportedEnergy = root.exportSteps.reduce((sum, s) => sum + s.y, 0);

            // Hourly rather than per 5 minutes: these counters step in
            // 100 Wh, too coarse to split a 5-minute step by route.
            const hours = totals.map(() => new Array(24).fill(0));
            totals.forEach((id, i) => {
                for (const s of steps(id))
                    hours[i][Math.min(23, Math.max(0, Math.floor(s.x)))] += s.y;
            });
            let flows = EnergyFlows.empty();
            for (let h = 0; h < 24; ++h)
                flows = EnergyFlows.add(flows, EnergyFlows.split(hours[0][h], hours[1][h], hours[2][h], hours[3][h], hours[4][h]));
            root.energyFlows = flows;
        });
    }

    // Yesterday's and this week's production and forecasts.
    function refreshDays() {
        const start = Math.min(root.yesterday, root.weekStart);
        const midnight = root.midnight;
        const yesterday = root.yesterday;
        root.statistics([root.solarPowerEntity], yesterday, "5minute", ["mean"], result => {
            root.solarYesterday = (result[root.solarPowerEntity] ?? []).filter(r => r.mean !== null && r.start < midnight).map(r => ({
                        x: (r.start - yesterday) / 3600000 + 2.5 / 60,
                        y: r.mean
                    }));
        });
        root.statistics([root.solarEnergyTotalEntity], start, "hour", ["change"], result => {
            const days = {};
            for (const r of result[root.solarEnergyTotalEntity] ?? []) {
                const day = new Date(r.start).setHours(0, 0, 0, 0);
                days[day] = (days[day] ?? 0) + (r.change ?? 0);
            }
            root.dailySolar = days;
        });
        // The forecast sensor's state is the day's total, and moves to the
        // next day's at midnight: a day's forecast is its last state that day.
        // The first entry is the state at `start`, left over from the day
        // before, so it's skipped.
        HassAPI.command("history/history_during_period", {
            start_time: new Date(start).toISOString(),
            entity_ids: [root.solarForecastEntity],
            minimal_response: true,
            no_attributes: true,
            significant_changes_only: false
        }, root, (ok, json) => {
            if (!ok)
                return;
            const unit = forecast.attributes.unit_of_measurement ?? "kWh";
            const scale = unit.startsWith("k") ? 1000 : 1;
            const days = {};
            const entries = JSON.parse(json)[root.solarForecastEntity] ?? [];
            for (let i = 1; i < entries.length; ++i) {
                const value = Number(entries[i].s);
                if (entries[i].s === "" || isNaN(value))
                    continue;
                days[new Date(entries[i].lu * 1000).setHours(0, 0, 0, 0)] = value * scale;
            }
            root.dailyForecast = days;
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
    Instantiator {
        id: forecastDays
        model: root.solarForecastDayEntities

        delegate: HassEntity {
            required property var modelData
            entityId: modelData
        }
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
        onTriggered: {
            root.refreshWeek();
            root.refreshDays();
        }
    }
    // Today's series restart at midnight, and today becomes yesterday.
    onMidnightChanged: {
        root.refreshToday();
        root.refreshDays();
    }

    Component.onCompleted: {
        root.refreshToday();
        root.refreshWeek();
        root.refreshDays();
    }
}
