import QtQuick

import QtHomeAssistant

// The office panel's energy page: which Home Assistant entities EnergyFlowPage
// reads. See HassEnergySource for what each one has to provide (units, signs,
// statistics).
EnergyFlowPage {
    // Live power
    solarPowerEntity: "sensor.selfa_inverter_pv_input_power"
    // Import-positive: sensor.selfa_inverter_grid_meter_power is the opposite
    // sign.
    gridPowerEntity: "sensor.selfa_inverter_grid_meter_power_inverted"
    batteryPowerEntity: "sensor.selfa_inverter_battery_power"
    homePowerEntity: "sensor.selfa_inverter_home_power"

    // Home consumers: the Energy dashboard's individual devices, except the
    // car, which is read from evcc like the power-flow cards do.
    consumerEntities: [
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
    batterySocEntity: "sensor.selfa_inverter_battery_soc"
    batteryMinSocEntity: "sensor.selfa_inverter_battery_low_soc_limit"
    batteryCapacityEntity: "sensor.selfa_inverter_selfa_battery_capacity"
    // Not exposed by the inverter integration; its battery power scheduling
    // limit is 5 kW.
    batteryMaxPower: 5000

    // Energy today
    solarEnergyTodayEntity: "sensor.selfa_inverter_daily_pv_generation"
    homeEnergyTodayEntity: "sensor.selfa_inverter_daily_load_consumption"

    // Energy totals, for history
    gridImportTotalEntity: "sensor.selfa_inverter_total_grid_purchase"
    gridExportTotalEntity: "sensor.selfa_inverter_total_grid_injection"
    batteryChargeTotalEntity: "sensor.selfa_inverter_energy_charged_into_battery"
    batteryDischargeTotalEntity: "sensor.selfa_inverter_energy_discharged_from_battery"
    homeEnergyTotalEntity: "sensor.selfa_inverter_home_energy"
    solarEnergyTotalEntity: "sensor.selfa_inverter_total_pv_generation"

    // Solar forecast (Solcast)
    solarForecastEntity: "sensor.solcast_pv_forecast_prognoza_na_dzisiaj"
    // From tomorrow on.
    solarForecastDayEntities: ["sensor.solcast_pv_forecast_prognoza_na_jutro", "sensor.solcast_pv_forecast_prognoza_na_dzien_3", "sensor.solcast_pv_forecast_prognoza_na_dzien_4", "sensor.solcast_pv_forecast_prognoza_na_dzien_5", "sensor.solcast_pv_forecast_prognoza_na_dzien_6", "sensor.solcast_pv_forecast_prognoza_na_dzien_7"]

    // Prices (Pstryk)
    buyPriceEntity: "sensor.pstryk_current_buy_price"
    sellPriceEntity: "sensor.pstryk_current_sell_price"
}
