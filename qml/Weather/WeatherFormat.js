.pragma library

// Formatting shared by the weather card and the screensaver's weather line.

// Home Assistant's condition ("partlycloudy") as HA's frontend names it.
function conditionName(condition) {
    switch (condition) {
    case "clear-night":
        return qsTr("Clear night");
    case "cloudy":
        return qsTr("Cloudy");
    case "exceptional":
        return qsTr("Exceptional");
    case "fog":
        return qsTr("Fog");
    case "hail":
        return qsTr("Hail");
    case "lightning":
        return qsTr("Lightning");
    case "lightning-rainy":
        return qsTr("Lightning, rainy");
    case "partlycloudy":
        return qsTr("Partly cloudy");
    case "pouring":
        return qsTr("Pouring");
    case "rainy":
        return qsTr("Rainy");
    case "snowy":
        return qsTr("Snowy");
    case "snowy-rainy":
        return qsTr("Snowy, rainy");
    case "sunny":
        return qsTr("Sunny");
    case "windy":
        return qsTr("Windy");
    case "windy-variant":
        return qsTr("Windy, cloudy");
    default:
        return condition;
    }
}

// At most one decimal, none when whole, in the locale's format.
function number(value) {
    const n = Number(value);
    return isNaN(n) ? String(value) : Number(Math.round(n * 10) / 10).toLocaleString(Qt.locale(), "f", Number.isInteger(Math.round(n * 10) / 10) ? 0 : 1);
}
