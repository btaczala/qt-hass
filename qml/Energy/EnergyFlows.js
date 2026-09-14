.pragma library

// How solar, grid and battery readings split into routes between the four
// circles of an EnergyFlowCard, the way power-flow-card-plus does it: export
// and battery charging are served from solar first, anything left from the
// battery or the grid respectively, and home gets the rest. Works the same for
// power (W) and energy (Wh); all inputs are non-negative.
//
// The result carries the inputs too, so a sum of results (add()) is a
// complete set of totals.
function split(solar, gridImport, gridExport, batteryCharge, batteryDischarge) {
    const solarToGrid = Math.min(gridExport, solar);
    const batteryToGrid = Math.min(batteryDischarge, gridExport - solarToGrid);
    const solarToBattery = Math.min(batteryCharge, solar - solarToGrid);
    const gridToBattery = Math.min(gridImport, batteryCharge - solarToBattery);
    const solarToHome = Math.max(0, solar - solarToGrid - solarToBattery);
    const batteryToHome = Math.max(0, batteryDischarge - batteryToGrid);
    const gridToHome = Math.max(0, gridImport - gridToBattery);
    return {
        solar: solar,
        gridImport: gridImport,
        gridExport: gridExport,
        batteryCharge: batteryCharge,
        batteryDischarge: batteryDischarge,
        solarToGrid: solarToGrid,
        batteryToGrid: batteryToGrid,
        solarToBattery: solarToBattery,
        gridToBattery: gridToBattery,
        solarToHome: solarToHome,
        batteryToHome: batteryToHome,
        gridToHome: gridToHome,
        home: solarToHome + batteryToHome + gridToHome
    };
}

function empty() {
    return split(0, 0, 0, 0, 0);
}

// Key-wise sum of two split() results.
function add(a, b) {
    const sum = {};
    for (const key in a)
        sum[key] = a[key] + b[key];
    return sum;
}
