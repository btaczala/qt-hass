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
        // shown; this area only decides the scale, picked so the expanded card
        // still fits.
        Item {
            id: cardArea
            Layout.fillWidth: true
            Layout.fillHeight: true

            EnergyFlowCard {
                id: card
                anchors.horizontalCenter: parent.horizontalCenter
                diagramScale: Math.min((cardArea.width - card.leftPadding - card.rightPadding) / card.designWidth,
                                       (cardArea.height - card.topPadding - card.bottomPadding) / card.expandedHeight)

                solarPower: source.solarPower
                gridPower: source.gridPower
                batteryPower: source.batteryPower
                batterySoc: source.batterySoc
                evPower: source.evPower
                heatPumpPower: source.heatPumpPower
            }
        }
    }
}
