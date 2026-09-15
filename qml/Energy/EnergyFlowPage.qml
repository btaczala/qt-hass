pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Material

import QtHomeAssistant

// A whole energy page: power flowing between solar, battery, grid and home
// right now, or energy since midnight, from Home Assistant (HassEnergySource);
// tapping a circle opens its details. Every entity it reads is a required
// property, passed on as-is to HassEnergySource, which documents what each one
// has to provide (units, signs, statistics).
Item {
    id: root

    // Live power
    required property string solarPowerEntity
    // Import-positive.
    required property string gridPowerEntity
    required property string batteryPowerEntity
    required property string homePowerEntity

    // Home consumers: [{name, icon, entity, insideOf}], see HassEnergySource.
    required property var consumerEntities

    // Battery
    required property string batterySocEntity
    required property string batteryMinSocEntity
    required property string batteryCapacityEntity
    // In W.
    required property real batteryMaxPower

    // Energy today
    required property string solarEnergyTodayEntity
    required property string homeEnergyTodayEntity

    // Energy totals, for history
    required property string gridImportTotalEntity
    required property string gridExportTotalEntity
    required property string batteryChargeTotalEntity
    required property string batteryDischargeTotalEntity
    required property string homeEnergyTotalEntity
    required property string solarEnergyTotalEntity

    // Solar forecast (Solcast)
    required property string solarForecastEntity
    // From tomorrow on.
    required property var solarForecastDayEntities

    // Prices (Pstryk)
    required property string buyPriceEntity
    required property string sellPriceEntity

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

    // The card sizes itself to its diagram; this area only decides the
    // scale, the largest at which it fits.
    Item {
        id: cardArea
        anchors.fill: parent
        anchors.margins: 40

        EnergyFlowCard {
            id: card
            anchors.horizontalCenter: parent.horizontalCenter
            diagramScale: Math.min((cardArea.width - card.leftPadding - card.rightPadding) / card.designWidth, (cardArea.height - card.topPadding - card.bottomPadding) / card.designHeight)

            mode: powerButton.checked ? "energy" : "power"
            solarPower: source.solarPower
            gridPower: source.gridPower
            batteryPower: source.batteryPower
            batterySoc: source.batterySoc
            energy: source.energyFlows

            onDetailsRequested: node => {
                details.node = node;
                details.open();
            }
            Button {
                id: powerButton
                anchors.right: parent.right
                checkable: true
                MdiIcon {
                    icon: powerButton.checked ? "mdi:power-plug-outline" : "mdi:solar-panel-large"
                    anchors.centerIn: parent
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
