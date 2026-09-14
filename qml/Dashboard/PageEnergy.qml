pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

import QtHomeAssistant

// Energy overview: power flowing between solar, battery, grid and home. Fed by
// FakeEnergySource for now, to try out the look; swap in real sensor readings
// by binding EnergyFlowCard's inputs to HA entities instead.
Item {
    id: root

    FakeEnergySource {
        id: source
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 8

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Simulated data · %1").arg(source.timeText)
            color: root.Material.hintTextColor
        }

        // The card sizes itself and grows downwards when its consumers row is
        // shown; this area only decides the scale, picked so the *collapsed*
        // card (the default state) fills the available space -- fitting the
        // expanded height instead left the diagram tiny on short/square
        // screens (confirmed on an NSPanel Pro) for a row that's hidden most
        // of the time. clip: true crops the consumers row instead, on screens
        // too short for it once the diagram is scaled up like this.
        Item {
            id: cardArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            EnergyFlowCard {
                id: card
                anchors.horizontalCenter: parent.horizontalCenter
                diagramScale: Math.min((cardArea.width - card.leftPadding - card.rightPadding) / card.designWidth,
                                       (cardArea.height - card.topPadding - card.bottomPadding) / card.collapsedHeight)

                solarPower: source.solarPower
                gridPower: source.gridPower
                batteryPower: source.batteryPower
                batterySoc: source.batterySoc
                evPower: source.evPower
                heatPumpPower: source.heatPumpPower

                onDetailsRequested: node => {
                    details.node = node;
                    details.open();
                }
            }
        }
    }

    EnergyDetailPopup {
        id: details

        // "solar", "grid" or "battery", as sent by the card.
        property string node

        title: details.node === "solar" ? qsTr("Solar") : details.node === "grid" ? qsTr("Grid") : qsTr("Battery")
        icon: details.node === "solar" ? "mdi:solar-power" : details.node === "grid" ? "mdi:transmission-tower" : card.batteryIcon(source.batterySoc, source.batteryPower < 0)
        accent: details.node === "solar" ? card.solarColor : details.node === "grid" ? card.gridImportColor : card.batteryDischargeColor
        content: details.node === "solar" ? solarDetails : details.node === "grid" ? gridDetails : batteryDetails
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
            loadProfile: source.loadProfile
            chargeColor: card.batteryChargeColor
            dischargeColor: card.batteryDischargeColor
        }
    }
}
