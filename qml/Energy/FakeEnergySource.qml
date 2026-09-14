import QtQuick

// Stand-in for real Home Assistant energy sensors, so the energy page can be
// looked at before it's wired up: simulates a day of a home with solar, a
// battery, an EV and a heat pump, compressed into a few minutes, so every flow
// direction (export, battery charging and discharging, grid import) comes up.
// Outputs follow EnergyFlowCard's sign conventions.
//
// Besides the live readings it keeps the series the detail overlays chart,
// shaped like what HA would provide: a solar forecast (Forecast.Solar /
// Solcast), hourly import and export prices (Nord Pool / Tibber / ENTSO-E),
// and a week of battery SoC history (the recorder). Chart series are arrays of
// {x, y} with x in hours.
Item {
    id: root

    // Real milliseconds per simulation step, and simulated minutes per step.
    // The defaults run a whole day in four minutes.
    property int stepInterval: 500
    property real minutesPerStep: 3

    property real batteryCapacity: 10000 // Wh
    property real batteryMaxPower: 2500
    property real batteryMinSoc: 10
    property real solarPeak: 6500

    // Prices are per kWh in this currency. Import pays the spot price plus
    // distribution fees, with VAT on top; export is paid the bare spot price,
    // which can go negative around a sunny midday.
    property string currency: "zł"
    property real importFees: 0.45
    property real vat: 0.23

    // Simulated clock, starting just before sunrise.
    property real minuteOfDay: 5.5 * 60
    // Simulated days since the start. History x values are `day * 24 + hour`,
    // so they keep increasing across midnight.
    property int day: 0
    readonly property real hour: root.minuteOfDay / 60
    readonly property real absoluteHour: root.day * 24 + root.hour
    readonly property string timeText: root.formatTime(root.minuteOfDay)

    property real solarPower: 0
    property real gridPower: 0
    property real batteryPower: 0
    property real batterySoc: 35
    property real evPower: 0
    property real heatPumpPower: 0

    // Today's solar forecast, quarter-hourly from 0:00 to 24:00, in W.
    property var solarForecast: []
    // Today's actual production so far: quarter-hour averages, then the live
    // reading.
    property var solarActual: []
    // Today's prices, one point per hour; each holds until the next hour.
    property var importPrices: []
    property var exportPrices: []
    // Typical home consumption in W, one point per hour.
    property var loadProfile: []
    // Hourly battery SoC over the last seven days.
    property var socHistory: []

    // Totals since midnight: Wh, and money in `currency`.
    property real solarEnergy: 0
    property real importedEnergy: 0
    property real exportedEnergy: 0
    property real importCost: 0
    property real exportRevenue: 0

    // Internal state, smoothed between steps so values drift rather than jump.
    // Actual cloud cover follows today's forecast, plus an error that wanders.
    property real clearness: 0.8
    property real cloudPhase: 0
    property real forecastError: 0
    property real baseLoad: 350
    property var actualBuckets: []
    property real bucketSum: 0
    property int bucketSteps: 0

    function formatTime(minutes: real): string {
        const m = Math.floor(minutes) % (24 * 60);
        return String(Math.floor(m / 60)).padStart(2, "0") + ":" + String(m % 60).padStart(2, "0");
    }

    // A daylight arch between 6:00 and 20:00.
    function daylight(h: real): real {
        return Math.max(0, Math.sin(Math.PI * (h - 6) / 14));
    }

    // Fraction of clear-sky production let through by clouds.
    function skyFactor(h: real, clearness: real, phase: real): real {
        return Math.min(1, Math.max(0.3, clearness + 0.18 * Math.sin(2 * Math.PI * h / 9 + phase)));
    }

    function bump(h: real, center: real, width: real): real {
        const d = (h - center) / width;
        return Math.exp(-d * d / 2);
    }

    // Morning and evening peaks on top of the base load.
    function peakLoad(h: real): real {
        let load = 0;
        if (h >= 6.5 && h < 8)
            load += 900;
        if (h >= 17.5 && h < 21.5)
            load += 1300;
        return load;
    }

    // EV charges around midday, when there's solar to use.
    function evLoad(h: real): real {
        return h >= 11 && h < 14.5 ? 3700 : 0;
    }

    // Battery takes solar surplus first and covers deficits first; the grid
    // gets whatever is left in either direction. Returns battery W, positive
    // while discharging.
    function dispatch(solar: real, home: real, soc: real, stepHours: real): real {
        const surplus = solar - home;
        if (surplus > 0) {
            const room = (100 - soc) / 100 * root.batteryCapacity / stepHours;
            return -Math.min(surplus, root.batteryMaxPower, room);
        }
        const available = Math.max(0, soc - root.batteryMinSoc) / 100 * root.batteryCapacity / stepHours;
        return Math.min(-surplus, root.batteryMaxPower, available);
    }

    function startDay() {
        root.clearness = 0.45 + Math.random() * 0.5;
        root.cloudPhase = Math.random() * 2 * Math.PI;

        const forecast = [];
        for (let q = 0; q <= 96; ++q) {
            const h = q / 4;
            forecast.push({
                x: h,
                y: Math.round(root.solarPeak * root.daylight(h) * root.skyFactor(h, root.clearness, root.cloudPhase))
            });
        }
        root.solarForecast = forecast;

        // Spot price: morning and evening peaks, dipping under the midday solar
        // glut the more so the sunnier the day.
        const imports = [];
        const exports = [];
        for (let h = 0; h < 24; ++h) {
            const mid = h + 0.5;
            const spot = 0.4 + 0.35 * root.bump(mid, 19, 1.8) + 0.15 * root.bump(mid, 7.5, 1.2) - 0.55 * root.clearness * root.bump(mid, 13, 2.5) + (Math.random() - 0.5) * 0.06;
            imports.push({
                x: h,
                y: Math.round((spot + root.importFees) * (1 + root.vat) * 100) / 100
            });
            exports.push({
                x: h,
                y: Math.round(spot * 100) / 100
            });
        }
        root.importPrices = imports;
        root.exportPrices = exports;

        root.actualBuckets = [];
        root.bucketSum = 0;
        root.bucketSteps = 0;
        root.solarEnergy = 0;
        root.importedEnergy = 0;
        root.exportedEnergy = 0;
        root.importCost = 0;
        root.exportRevenue = 0;
    }

    function step() {
        const hours = root.hour;
        const stepHours = root.minutesPerStep / 60;

        root.forecastError = Math.min(0.25, Math.max(-0.25, root.forecastError + (Math.random() - 0.5) * 0.08));
        const sky = Math.min(1, Math.max(0.2, root.skyFactor(hours, root.clearness, root.cloudPhase) + root.forecastError));
        root.solarPower = Math.round(root.solarPeak * root.daylight(hours) * sky);

        // Home: always-on base load wandering around, plus peaks.
        root.baseLoad = Math.min(700, Math.max(200, root.baseLoad + (Math.random() - 0.5) * 80));
        root.evPower = root.evLoad(hours);

        // Heat pump cycles on and off.
        if (root.heatPumpPower > 0 ? Math.random() < 0.08 : Math.random() < 0.05)
            root.heatPumpPower = root.heatPumpPower > 0 ? 0 : 1100;
        else if (root.heatPumpPower > 0)
            root.heatPumpPower = Math.round(Math.min(1500, Math.max(800, root.heatPumpPower + (Math.random() - 0.5) * 150)));

        const home = root.baseLoad + root.peakLoad(hours) + root.evPower + root.heatPumpPower;
        const battery = root.dispatch(root.solarPower, home, root.batterySoc, stepHours);
        root.batteryPower = Math.round(battery);
        root.gridPower = Math.round(home - root.solarPower - battery);
        root.batterySoc = Math.min(100, Math.max(0, root.batterySoc - battery * stepHours / root.batteryCapacity * 100));

        const priceHour = Math.floor(hours);
        const imported = Math.max(0, root.gridPower) * stepHours;
        const exported = Math.max(0, -root.gridPower) * stepHours;
        root.solarEnergy += root.solarPower * stepHours;
        root.importedEnergy += imported;
        root.exportedEnergy += exported;
        root.importCost += imported / 1000 * root.importPrices[priceHour].y;
        root.exportRevenue += exported / 1000 * root.exportPrices[priceHour].y;

        root.bucketSum += root.solarPower;
        root.bucketSteps += 1;

        // Advance the clock, closing the quarter hour, hour and day as they
        // pass.
        const previous = root.minuteOfDay;
        const next = previous + root.minutesPerStep;
        if (Math.floor(next / 15) !== Math.floor(previous / 15)) {
            const bucketStart = Math.floor(previous / 15) * 15 / 60;
            root.actualBuckets.push({
                x: bucketStart + 0.125,
                y: Math.round(root.bucketSum / root.bucketSteps)
            });
            root.bucketSum = 0;
            root.bucketSteps = 0;
        }
        if (Math.floor(next / 60) !== Math.floor(previous / 60)) {
            const now = root.day * 24 + Math.floor(next / 60);
            root.socHistory = root.socHistory.filter(p => p.x > now - 7 * 24).concat([{
                        x: now,
                        y: root.batterySoc
                    }]);
        }
        if (next >= 24 * 60) {
            root.day += 1;
            root.minuteOfDay = next - 24 * 60;
            root.startDay();
        } else {
            root.minuteOfDay = next;
        }

        root.solarActual = root.actualBuckets.concat([{
                    x: root.hour,
                    y: root.solarPower
                }]);
    }

    // A week of made-up history before the start, from the same model at
    // half-hour steps with a fresh random sky each day; it ends at the start
    // time with the SoC the live simulation then carries on from.
    function fillHistory() {
        const stepHours = 0.5;
        const start = root.hour;
        const history = [];
        let soc = root.batterySoc;
        let clearness = 0.7;
        let phase = 0;
        for (let t = start - 7 * 24; t < start; t += stepHours) {
            const h = ((t % 24) + 24) % 24;
            if (h < stepHours) {
                clearness = 0.35 + Math.random() * 0.6;
                phase = Math.random() * 2 * Math.PI;
            }
            if (h === Math.floor(h))
                history.push({
                    x: t,
                    y: soc
                });
            const solar = root.solarPeak * root.daylight(h) * root.skyFactor(h, clearness, phase);
            const home = 450 + root.peakLoad(h) + root.evLoad(h) + (Math.random() < 0.4 ? 1100 : 0);
            const battery = root.dispatch(solar, home, soc, stepHours);
            soc = Math.min(100, Math.max(0, soc - battery * stepHours / root.batteryCapacity * 100));
        }
        root.socHistory = history;
        root.batterySoc = soc;

        // Buckets before the start time: still night, so nothing produced.
        const buckets = [];
        for (let q = 0; q < Math.floor(root.minuteOfDay / 15); ++q)
            buckets.push({
                x: q / 4 + 0.125,
                y: 0
            });
        root.actualBuckets = buckets;
    }

    Component.onCompleted: {
        // Average base load, heat pump duty cycle (on ~40% of the time at
        // ~1.1 kW) and the scheduled peaks.
        const profile = [];
        for (let h = 0; h < 24; ++h) {
            let sum = 0;
            for (let q = 0; q < 4; ++q) {
                const t = h + q / 4;
                sum += 450 + 440 + root.peakLoad(t) + root.evLoad(t);
            }
            profile.push({
                x: h,
                y: Math.round(sum / 4)
            });
        }
        root.loadProfile = profile;

        root.startDay();
        root.fillHistory();
        timer.start();
    }

    Timer {
        id: timer
        interval: root.stepInterval
        repeat: true
        triggeredOnStart: true
        onTriggered: root.step()
    }
}
