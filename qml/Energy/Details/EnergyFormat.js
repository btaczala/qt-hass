.pragma library

// Number formatting shared by the energy detail overlays.

function power(watts) {
    const w = Math.abs(watts);
    if (w < 1000)
        return Math.round(w) + " W";
    return (w / 1000).toFixed(w < 10000 ? 2 : 1) + " kW";
}

function energy(wattHours) {
    return (wattHours / 1000).toFixed(1) + " kWh";
}

function money(amount, currency) {
    return amount.toFixed(2) + " " + currency;
}

function price(amount, currency) {
    return amount.toFixed(2) + " " + currency + "/kWh";
}

// "HH:MM" for a time of day in hours; wraps past midnight.
function clock(hours) {
    const minutes = Math.round(hours * 60) % (24 * 60);
    return String(Math.floor(minutes / 60)).padStart(2, "0") + ":" + String(minutes % 60).padStart(2, "0");
}

// "2 h 05 min" / "45 min".
function duration(hours) {
    const minutes = Math.round(hours * 60);
    if (minutes < 60)
        return minutes + " min";
    return Math.floor(minutes / 60) + " h " + String(minutes % 60).padStart(2, "0") + " min";
}
