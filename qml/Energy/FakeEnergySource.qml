import QtQuick

// Stand-in for real Home Assistant energy sensors, so the energy page can be
// looked at before it's wired up: simulates a day of a home with solar, a
// battery, an EV and a heat pump, compressed into a few minutes, so every flow
// direction (export, battery charging and discharging, grid import) comes up.
// Outputs follow EnergyFlowCard's sign conventions.
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

    // Simulated clock, starting just before sunrise.
    property real minuteOfDay: 5.5 * 60
    readonly property string timeText: {
        const minutes = Math.floor(root.minuteOfDay);
        return String(Math.floor(minutes / 60)).padStart(2, "0") + ":" + String(minutes % 60).padStart(2, "0");
    }

    property real solarPower: 0
    property real gridPower: 0
    property real batteryPower: 0
    property real batterySoc: 35
    property real evPower: 0
    property real heatPumpPower: 0

    // Internal state, smoothed between steps so values drift rather than jump.
    property real clouds: 1
    property real baseLoad: 350

    function step() {
        const hours = root.minuteOfDay / 60;
        const stepHours = root.minutesPerStep / 60;

        // Solar: a daylight arch between 6:00 and 20:00, dimmed by drifting
        // clouds.
        root.clouds = Math.min(1, Math.max(0.35, root.clouds + (Math.random() - 0.5) * 0.15));
        const daylight = Math.max(0, Math.sin(Math.PI * (hours - 6) / 14));
        root.solarPower = Math.round(root.solarPeak * daylight * root.clouds);

        // Home: always-on base load wandering around, plus morning and
        // evening peaks.
        root.baseLoad = Math.min(700, Math.max(200, root.baseLoad + (Math.random() - 0.5) * 80));
        let load = root.baseLoad;
        if (hours >= 6.5 && hours < 8)
            load += 900;
        if (hours >= 17.5 && hours < 21.5)
            load += 1300;

        // EV charges around midday, when there's solar to use.
        root.evPower = hours >= 11 && hours < 14.5 ? 3700 : 0;

        // Heat pump cycles on and off.
        if (root.heatPumpPower > 0 ? Math.random() < 0.08 : Math.random() < 0.05)
            root.heatPumpPower = root.heatPumpPower > 0 ? 0 : 1100;
        else if (root.heatPumpPower > 0)
            root.heatPumpPower = Math.round(Math.min(1500, Math.max(800, root.heatPumpPower + (Math.random() - 0.5) * 150)));

        const home = load + root.evPower + root.heatPumpPower;
        const surplus = root.solarPower - home;

        // Battery takes solar surplus first and covers deficits first; the grid
        // gets whatever is left in either direction.
        let battery = 0;
        if (surplus > 0) {
            const room = (100 - root.batterySoc) / 100 * root.batteryCapacity / stepHours;
            battery = -Math.min(surplus, root.batteryMaxPower, room);
        } else {
            const available = Math.max(0, root.batterySoc - root.batteryMinSoc) / 100 * root.batteryCapacity / stepHours;
            battery = Math.min(-surplus, root.batteryMaxPower, available);
        }
        root.batteryPower = Math.round(battery);
        root.gridPower = Math.round(-surplus - battery);
        root.batterySoc = Math.min(100, Math.max(0, root.batterySoc - battery * stepHours / root.batteryCapacity * 100));

        root.minuteOfDay = (root.minuteOfDay + root.minutesPerStep) % (24 * 60);
    }

    Timer {
        interval: root.stepInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.step()
    }
}
