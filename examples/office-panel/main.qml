import QtQuick

import QtHomeAssistant

// The office panel's dashboard: the root file the app's dashboard URL points
// at, e.g. http://homeassistant.local:8123/local/qthass/main.qml after copying
// this directory to Home Assistant's /config/www/qthass/. The other files are
// listed in qmldir, so they're downloaded with it.
Dashboard {
    screensaverWeatherEntity: "weather.pirateweather"
    // The same sensors as OfficeEnergy.qml.
    screensaverEnergyEntities: ({
            solarPower: "sensor.selfa_inverter_pv_input_power",
            homePower: "sensor.selfa_inverter_home_power",
            gridPower: "sensor.selfa_inverter_grid_meter_power_inverted",
            batteryPower: "sensor.selfa_inverter_battery_power",
            batterySoc: "sensor.selfa_inverter_battery_soc",
            solarEnergyToday: "sensor.selfa_inverter_daily_pv_generation",
            homeEnergyToday: "sensor.selfa_inverter_daily_load_consumption",
            solarForecastToday: "sensor.solcast_pv_forecast_prognoza_na_dzisiaj"
        })

    pages: [
        DashboardPage {
            title: qsTr("Overview")
            icon: "mdi:view-dashboard"
            OfficeOverview {
                anchors.fill: parent
            }
        },
        DashboardPage {
            title: qsTr("Energy")
            icon: "mdi:lightning-bolt"
            OfficeEnergy {
                anchors.fill: parent
            }
        },
        DashboardPage {
            title: qsTr("Cameras")
            icon: "mdi:cctv"
            OfficeCameras {
                anchors.fill: parent
            }
        }
    ]

    OfficeDoNotDisturb {
        entityId: "input_boolean.bartek_nie_przeszkadac"
    }
}
