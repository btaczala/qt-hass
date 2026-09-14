pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts

import QtHomeAssistant

// Energy overview: power flowing between solar, battery, grid and home right
// now, or energy since midnight, from Home Assistant (HassEnergySource);
// tapping a circle opens its details.
Item {
    id: root

    // Every Home Assistant entity this page reads. See HassEnergySource for
    // what each one has to provide (units, signs, statistics).

    // Live power
    readonly property string solarPowerEntity: "sensor.selfa_inverter_pv_input_power"
    // Import-positive: sensor.selfa_inverter_grid_meter_power is the opposite
    // sign.
    readonly property string gridPowerEntity: "sensor.selfa_inverter_grid_meter_power_inverted"
    readonly property string batteryPowerEntity: "sensor.selfa_inverter_battery_power"
    readonly property string homePowerEntity: "sensor.selfa_inverter_home_power"

    // Home consumers: the Energy dashboard's individual devices, except the
    // car, which is read from evcc like the power-flow cards do.
    readonly property var consumerEntities: [
        {
            name: "JCW",
            icon: "mdi:car-electric",
            entity: "sensor.evcc_garage_charge_power"
        },
        {
            name: "Rack",
            icon: "mdi:server-network",
            entity: "sensor.shelly_mini_rack_power"
        },
        {
            name: "Biurko główne w biurze",
            icon: "mdi:desk",
            entity: "sensor.tapo_smart_plug_biurko_glowne_moc_1"
        },
        {
            name: "Biurko drugie w biurze",
            icon: "mdi:desktop-tower-monitor",
            entity: "sensor.tapo_smart_plug_biurko_drugie_moc_1"
        },
        {
            name: "VS Servers rack",
            icon: "mdi:server",
            entity: "sensor.shelly_pm_mini_vs_rack_moc",
            insideOf: "sensor.tapo_smart_plug_biurko_drugie_moc_1"
        },
        {
            name: "Albert biurko",
            icon: "mdi:desk",
            entity: "sensor.shelly_plug_albert_biuro_switch_0_power"
        },
        {
            name: "Albert TV",
            icon: "mdi:television",
            entity: "sensor.shelly_plug_albert_tv_switch_0_power"
        },
        {
            name: "Szafka RTV",
            icon: "mdi:television-classic",
            entity: "sensor.shelly_plug_szafka_rtv_switch_0_power"
        },
        {
            name: "Pralka",
            icon: "mdi:washing-machine",
            entity: "sensor.pralka_power"
        },
        {
            name: "Zmywarka",
            icon: "mdi:dishwasher",
            entity: "sensor.grillplats_plug_moc"
        },
        {
            name: "Lodówka",
            icon: "mdi:fridge",
            entity: "sensor.gniazdko_lodowka_power"
        },
        {
            name: "Termowentylator w łazience na dole",
            icon: "mdi:fan",
            entity: "sensor.shelly_plug_s_lazienka_dol_switch_0_power"
        },
        {
            name: "Grzejnik",
            icon: "mdi:radiator",
            entity: "sensor.shelly_1_pm_grzejnik_power"
        },
        {
            name: "Shelly basen",
            icon: "mdi:pool",
            entity: "sensor.shellyoutdoorsg3_e4b3232d5408_power"
        },
        {
            name: "Ogród gniazdo",
            icon: "mdi:power-socket-eu",
            entity: "sensor.shelly_pm_gniazdo_ogrod_moc"
        }
    ]

    // Battery
    readonly property string batterySocEntity: "sensor.selfa_inverter_battery_soc"
    readonly property string batteryMinSocEntity: "sensor.selfa_inverter_battery_low_soc_limit"
    readonly property string batteryCapacityEntity: "sensor.selfa_inverter_selfa_battery_capacity"
    // Not exposed by the inverter integration; its battery power scheduling
    // limit is 5 kW.
    readonly property real batteryMaxPower: 5000

    // Energy today
    readonly property string solarEnergyTodayEntity: "sensor.selfa_inverter_daily_pv_generation"
    readonly property string homeEnergyTodayEntity: "sensor.selfa_inverter_daily_load_consumption"

    // Energy totals, for history
    readonly property string gridImportTotalEntity: "sensor.selfa_inverter_total_grid_purchase"
    readonly property string gridExportTotalEntity: "sensor.selfa_inverter_total_grid_injection"
    readonly property string batteryChargeTotalEntity: "sensor.selfa_inverter_energy_charged_into_battery"
    readonly property string batteryDischargeTotalEntity: "sensor.selfa_inverter_energy_discharged_from_battery"
    readonly property string homeEnergyTotalEntity: "sensor.selfa_inverter_home_energy"
    readonly property string solarEnergyTotalEntity: "sensor.selfa_inverter_total_pv_generation"

    // Solar forecast (Solcast)
    readonly property string solarForecastEntity: "sensor.solcast_pv_forecast_prognoza_na_dzisiaj"
    // From tomorrow on.
    readonly property var solarForecastDayEntities: [
        "sensor.solcast_pv_forecast_prognoza_na_jutro",
        "sensor.solcast_pv_forecast_prognoza_na_dzien_3",
        "sensor.solcast_pv_forecast_prognoza_na_dzien_4",
        "sensor.solcast_pv_forecast_prognoza_na_dzien_5",
        "sensor.solcast_pv_forecast_prognoza_na_dzien_6",
        "sensor.solcast_pv_forecast_prognoza_na_dzien_7"
    ]

    // Prices (Pstryk)
    readonly property string buyPriceEntity: "sensor.pstryk_current_buy_price"
    readonly property string sellPriceEntity: "sensor.pstryk_current_sell_price"

    HassEnergySource {
        id: source

        solarPowerEntity: root.solarPowerEntity
        gridPowerEntity: root.gridPowerEntity
        batteryPowerEntity: root.batteryPowerEntity
        homePowerEntity: root.homePowerEntity
        consumerEntities: root.consumerEntities
        batterySocEntity: root.batterySocEntity
        batteryMinSocEntity: root.batteryMinSocEntity
        batteryCapacityEntity: root.batteryCapacityEntity
        batteryMaxPower: root.batteryMaxPower
        solarEnergyTodayEntity: root.solarEnergyTodayEntity
        homeEnergyTodayEntity: root.homeEnergyTodayEntity
        gridImportTotalEntity: root.gridImportTotalEntity
        gridExportTotalEntity: root.gridExportTotalEntity
        batteryChargeTotalEntity: root.batteryChargeTotalEntity
        batteryDischargeTotalEntity: root.batteryDischargeTotalEntity
        homeEnergyTotalEntity: root.homeEnergyTotalEntity
        solarEnergyTotalEntity: root.solarEnergyTotalEntity
        solarForecastEntity: root.solarForecastEntity
        solarForecastDayEntities: root.solarForecastDayEntities
        buyPriceEntity: root.buyPriceEntity
        sellPriceEntity: root.sellPriceEntity
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 8

        TabBar {
            id: modeTabs
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 320
            Material.background: "transparent"

            TabButton {
                text: qsTr("Power now")
            }
            TabButton {
                text: qsTr("Energy today")
            }
        }

        // The card sizes itself to its diagram; this area only decides the
        // scale, the largest at which it fits.
        Item {
            id: cardArea
            Layout.fillWidth: true
            Layout.fillHeight: true

            EnergyFlowCard {
                id: card
                anchors.horizontalCenter: parent.horizontalCenter
                diagramScale: Math.min((cardArea.width - card.leftPadding - card.rightPadding) / card.designWidth,
                                       (cardArea.height - card.topPadding - card.bottomPadding) / card.designHeight)

                mode: modeTabs.currentIndex === 1 ? "energy" : "power"
                solarPower: source.solarPower
                gridPower: source.gridPower
                batteryPower: source.batteryPower
                batterySoc: source.batterySoc
                energy: source.energyFlows

                onDetailsRequested: node => {
                    details.node = node;
                    details.open();
                }
            }
        }
    }

    EnergyDetailPopup {
        id: details

        // "solar", "grid", "battery" or "home", as sent by the card.
        property string node

        readonly property var page: ({
                solar: {
                    title: qsTr("Solar"),
                    icon: "mdi:solar-power",
                    accent: card.solarColor,
                    content: solarDetails
                },
                grid: {
                    title: qsTr("Grid"),
                    icon: "mdi:transmission-tower",
                    accent: card.gridImportColor,
                    content: gridDetails
                },
                battery: {
                    title: qsTr("Battery"),
                    icon: card.batteryIcon(source.batterySoc, source.batteryPower < 0),
                    accent: card.batteryDischargeColor,
                    content: batteryDetails
                },
                home: {
                    title: qsTr("Home"),
                    icon: "mdi:home",
                    accent: root.Material.accentColor,
                    content: homeDetails
                }
            })[details.node] ?? null

        title: details.page?.title ?? ""
        icon: details.page?.icon ?? ""
        accent: details.page?.accent ?? root.Material.foreground
        content: details.page?.content ?? null
    }

    // Popups sit above the screensaver, so don't leave one open under it.
    Connections {
        target: Controler
        function onScreensaverActiveChanged() {
            if (Controler.screensaverActive)
                details.close();
        }
    }

    Component {
        id: solarDetails

        SolarDetail {
            power: source.solarPower
            producedEnergy: source.solarEnergy
            forecast: source.solarForecast
            actual: source.solarActual
            nowHour: source.hour
            yesterdayActual: source.solarYesterday
            yesterdayEnergy: source.solarYesterdayEnergy
            yesterdayForecast: source.solarYesterdayForecast
            today: source.midnight
            week: source.solarWeek
            color: card.solarColor
        }
    }

    Component {
        id: gridDetails

        GridDetail {
            power: source.gridPower
            importPrices: source.importPrices
            exportPrices: source.exportPrices
            currency: source.currency
            nowHour: source.hour
            importedEnergy: source.importedEnergy
            exportedEnergy: source.exportedEnergy
            importCost: source.importCost
            exportRevenue: source.exportRevenue
            importColor: card.gridImportColor
            exportColor: card.gridExportColor
        }
    }

    Component {
        id: homeDetails

        HomeDetail {
            power: card.homePower
            fromSolar: card.solarToHome
            fromBattery: card.batteryToHome
            fromGrid: card.gridToHome
            energyToday: source.homeEnergy
            importedToday: source.importedEnergy
            actual: source.homeActual
            nowHour: source.hour
            solarColor: card.solarColor
            batteryColor: card.batteryDischargeColor
            gridColor: card.gridImportColor
            consumers: source.consumers
        }
    }

    Component {
        id: batteryDetails

        BatteryDetail {
            soc: source.batterySoc
            power: source.batteryPower
            capacity: source.batteryCapacity
            maxPower: source.batteryMaxPower
            minSoc: source.batteryMinSoc
            nowHour: source.hour
            absoluteHour: source.absoluteHour
            history: source.socHistory
            solarForecast: source.solarForecast
            solarForecastLow: source.solarForecastLow
            solarForecastHigh: source.solarForecastHigh
            loadProfile: source.loadProfile
            chargeColor: card.batteryChargeColor
            dischargeColor: card.batteryDischargeColor
        }
    }
}
