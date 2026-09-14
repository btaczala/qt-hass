import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

import QtHomeAssistant

// Solar overlay: tabs for today (production against the forecast, live),
// yesterday, and this week day by day. Opens on today, as the popup creates
// its content afresh each time.
ColumnLayout {
    id: root

    property real power: 0
    // Wh produced since midnight.
    property real producedEnergy: 0
    // [{x: hour, y: W}], evenly spaced, covering the whole day.
    property var forecast: []
    // [{x: hour, y: W}] so far today.
    property var actual: []
    property real nowHour: 0
    // [{x: hour since yesterday's midnight, y: W}], and yesterday's total and
    // forecast (Wh, the forecast NaN if unknown).
    property var yesterdayActual: []
    property real yesterdayEnergy: 0
    property real yesterdayForecast: NaN
    // Today's midnight (ms), and this week as HassEnergySource.solarWeek.
    property real today: 0
    property var week: []
    property color color: "#ff9800"

    spacing: 12

    TabBar {
        id: tabs
        Layout.fillWidth: true

        TabButton {
            text: qsTr("Today")
        }
        TabButton {
            text: qsTr("Yesterday")
        }
        TabButton {
            text: qsTr("This week")
        }
    }

    // All tabs exist up front, so switching is instant and each chart is
    // only filled once.
    StackLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        currentIndex: tabs.currentIndex

        SolarDay {
            id: todayView
            power: root.power
            producedEnergy: root.producedEnergy
            forecast: root.forecast
            actual: root.actual
            nowHour: root.nowHour
            color: root.color
        }
        SolarDay {
            live: false
            producedEnergy: root.yesterdayEnergy
            forecastTotal: root.yesterdayForecast
            actual: root.yesterdayActual
            color: root.color
        }
        SolarWeek {
            days: root.week
            today: root.today
            todayForecastSoFar: todayView.forecastSoFar
            todayRemaining: todayView.forecastRemaining
            color: root.color
        }
    }
}
