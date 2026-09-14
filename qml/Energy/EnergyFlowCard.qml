pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Shapes

import QtHomeAssistant

// A power flow diagram in the style of power-flow-card-plus
// (github.com/flixlix/power-flow-card-plus): solar on top, grid on the left,
// battery on the right, home at the bottom, joined by lines with dots moving
// along every route power is taking. Tapping home fades in the individual
// consumers below it.
//
// Inputs are the same few instantaneous readings HA's energy sensors give; the
// per-route flows are derived from them the same way that card does -- export
// and battery charging are served from solar first, anything left from the
// grid or the battery respectively.
Pane {
    id: root

    // Watts. Sign conventions follow HA: grid positive while importing,
    // battery positive while discharging.
    property real solarPower: 0
    property real gridPower: 0
    property real batteryPower: 0
    property real batterySoc: 0
    property real evPower: 0
    property real heatPumpPower: 0

    // Whether the individual consumers below home are shown; toggled by
    // tapping home.
    property bool consumersVisible: false

    // Tapping solar, grid or battery asks for that node's details; `node` is
    // "solar", "grid" or "battery".
    signal detailsRequested(string node)

    // power-flow-card-plus / HA energy dashboard default colors.
    property color solarColor: "#ff9800"
    property color gridImportColor: "#488fc2"
    property color gridExportColor: "#8353d1"
    property color batteryChargeColor: "#f06292"
    property color batteryDischargeColor: "#4db6ac"
    property color evColor: "#9ccc65"
    property color heatPumpColor: "#ef5350"
    property color idleColor: Qt.rgba(root.Material.foreground.r, root.Material.foreground.g, root.Material.foreground.b, 0.2)

    readonly property real gridImport: Math.max(0, root.gridPower)
    readonly property real gridExport: Math.max(0, -root.gridPower)
    readonly property real batteryDischarge: Math.max(0, root.batteryPower)
    readonly property real batteryCharge: Math.max(0, -root.batteryPower)

    readonly property real solarToGrid: Math.min(root.gridExport, root.solarPower)
    readonly property real batteryToGrid: Math.min(root.batteryDischarge, root.gridExport - root.solarToGrid)
    readonly property real solarToBattery: Math.min(root.batteryCharge, root.solarPower - root.solarToGrid)
    readonly property real gridToBattery: Math.min(root.gridImport, root.batteryCharge - root.solarToBattery)
    readonly property real solarToHome: Math.max(0, root.solarPower - root.solarToGrid - root.solarToBattery)
    readonly property real batteryToHome: Math.max(0, root.batteryDischarge - root.batteryToGrid)
    readonly property real gridToHome: Math.max(0, root.gridImport - root.gridToBattery)
    readonly property real homePower: root.solarToHome + root.batteryToHome + root.gridToHome

    readonly property real maxFlow: Math.max(root.solarToHome, root.solarToGrid, root.solarToBattery, root.gridToHome, root.batteryToHome, root.gridToBattery, root.batteryToGrid, root.evPower, root.heatPumpPower)

    // The diagram is laid out in these fixed units, then drawn at
    // diagramScale. The card sizes itself to the diagram: collapsedHeight
    // without the consumers row, expandedHeight with it, animating between
    // the two as the row fades. diagramScale is picked (by PageEnergy.qml) to
    // fit collapsedHeight, so the default view isn't shrunk to make room for
    // a row that's hidden most of the time; on screens too short for the
    // expanded height too, the consumers row simply clips instead of
    // rescaling the whole diagram down.
    readonly property real designWidth: 580
    readonly property real collapsedHeight: 520
    readonly property real expandedHeight: 670
    property real diagramScale: 1

    // Current height of the visible part of the diagram, in design units.
    property real shownHeight: root.consumersVisible ? root.expandedHeight : root.collapsedHeight

    Behavior on shownHeight {
        NumberAnimation {
            duration: 250
            easing.type: Easing.InOutQuad
        }
    }
    // How far off-center lines that share a circle side attach.
    readonly property real attachOffset: 14

    function formatPower(watts: real): string {
        const w = Math.abs(watts);
        if (w < 1000)
            return Math.round(w) + " W";
        return (w / 1000).toFixed(w < 10000 ? 2 : 1) + " kW";
    }

    function batteryIcon(soc: real, charging: bool): string {
        const level = Math.round(soc / 10) * 10;
        if (charging)
            return "mdi:battery-charging-" + Math.max(10, level);
        if (level >= 100)
            return "mdi:battery";
        if (level <= 0)
            return "mdi:battery-outline";
        return "mdi:battery-" + level;
    }

    // Points on a node's circle, `offset` away from the center line of that
    // side.
    function topOf(node: EnergyNode, offset: real): point {
        return Qt.point(node.centerX + offset, node.centerY - Math.sqrt(node.radius * node.radius - offset * offset));
    }
    function bottomOf(node: EnergyNode, offset: real): point {
        return Qt.point(node.centerX + offset, node.centerY + Math.sqrt(node.radius * node.radius - offset * offset));
    }
    function leftOf(node: EnergyNode, offset: real): point {
        return Qt.point(node.centerX - Math.sqrt(node.radius * node.radius - offset * offset), node.centerY + offset);
    }
    function rightOf(node: EnergyNode, offset: real): point {
        return Qt.point(node.centerX + Math.sqrt(node.radius * node.radius - offset * offset), node.centerY + offset);
    }

    Material.elevation: 4
    Material.roundedScale: Material.MediumScale

    contentWidth: root.designWidth * root.diagramScale
    contentHeight: root.shownHeight * root.diagramScale

    // A value row inside a node: a direction arrow (optional) and a power.
    component FlowValue: RowLayout {
        id: flowValue

        property string icon
        property real watts
        property color color: Material.foreground

        Layout.alignment: Qt.AlignHCenter
        spacing: 1

        MdiIcon {
            visible: flowValue.icon !== ""
            icon: flowValue.icon
            iconSize: 11
            color: flowValue.color
        }
        Label {
            text: root.formatPower(flowValue.watts)
            font.pixelSize: 11
            color: flowValue.color
        }
    }

    // Clips the diagram to the card's current height, so the consumers row
    // doesn't spill below the card while it collapses.
    Item {
        anchors.fill: parent
        clip: true

        Item {
            id: diagram
            width: root.designWidth
            height: root.expandedHeight
            scale: root.diagramScale
            transformOrigin: Item.TopLeft

            // Lines first, so the circles and their contents draw on top.
            EnergyFlowLine {
                anchors.fill: parent
                from: root.bottomOf(solar, 0)
                to: root.topOf(home, 0)
                power: root.solarToHome
                maxPower: root.maxFlow
                color: root.solarColor
                idleColor: root.idleColor
            }
            EnergyFlowLine {
                anchors.fill: parent
                from: root.bottomOf(solar, -root.attachOffset)
                to: root.rightOf(grid, -root.attachOffset)
                control: Qt.point(from.x, to.y)
                power: root.solarToGrid
                maxPower: root.maxFlow
                color: root.gridExportColor
                idleColor: root.idleColor
            }
            EnergyFlowLine {
                anchors.fill: parent
                from: root.bottomOf(solar, root.attachOffset)
                to: root.leftOf(battery, -root.attachOffset)
                control: Qt.point(from.x, to.y)
                power: root.solarToBattery
                maxPower: root.maxFlow
                color: root.batteryChargeColor
                idleColor: root.idleColor
            }
            EnergyFlowLine {
                anchors.fill: parent
                from: root.rightOf(grid, 0)
                to: root.leftOf(battery, 0)
                power: root.gridToBattery - root.batteryToGrid
                maxPower: root.maxFlow
                color: power >= 0 ? root.gridImportColor : root.gridExportColor
                idleColor: root.idleColor
            }
            EnergyFlowLine {
                anchors.fill: parent
                from: root.rightOf(grid, root.attachOffset)
                to: root.topOf(home, -root.attachOffset)
                control: Qt.point(to.x, from.y)
                power: root.gridToHome
                maxPower: root.maxFlow
                color: root.gridImportColor
                idleColor: root.idleColor
            }
            EnergyFlowLine {
                anchors.fill: parent
                from: root.leftOf(battery, root.attachOffset)
                to: root.topOf(home, root.attachOffset)
                control: Qt.point(to.x, from.y)
                power: root.batteryToHome
                maxPower: root.maxFlow
                color: root.batteryDischargeColor
                idleColor: root.idleColor
            }

            EnergyNode {
                id: solar
                centerX: 290
                centerY: 100
                label: qsTr("Solar")
                icon: "mdi:solar-power"
                color: root.solarColor
                clickable: true
                onClicked: root.detailsRequested("solar")

                FlowValue {
                    watts: root.solarPower
                }
            }

            EnergyNode {
                id: grid
                centerX: 70
                centerY: 260
                labelBelow: true
                label: qsTr("Grid")
                icon: "mdi:transmission-tower"
                color: root.gridExport > root.gridImport ? root.gridExportColor : root.gridImportColor
                clickable: true
                onClicked: root.detailsRequested("grid")

                FlowValue {
                    icon: "mdi:arrow-left"
                    watts: root.gridExport
                    color: root.gridExportColor
                }
                FlowValue {
                    icon: "mdi:arrow-right"
                    watts: root.gridImport
                    color: root.gridImportColor
                }
            }

            EnergyNode {
                id: home
                centerX: 290
                centerY: 420
                labelBelow: true
                label: qsTr("Home")
                icon: "mdi:home"
                outlined: false
                clickable: true
                onClicked: root.consumersVisible = !root.consumersVisible

                FlowValue {
                    watts: root.homePower
                }
            }

            // Home's outline: a ring split by where its power is coming from,
            // clockwise from the top -- solar, battery, grid.
            Shape {
                id: ring
                x: home.x
                y: home.y
                width: home.width
                height: home.height
                preferredRendererType: Shape.CurveRenderer

                readonly property real total: Math.max(1, root.homePower)
                readonly property real solarSweep: 360 * root.solarToHome / ring.total
                readonly property real batterySweep: 360 * root.batteryToHome / ring.total
                readonly property real gridSweep: 360 * root.gridToHome / ring.total

                component RingSegment: ShapePath {
                    id: segment

                    property real startAngle
                    property real sweep
                    property color color

                    fillColor: "transparent"
                    strokeWidth: 2
                    // An empty segment would otherwise still leave a speck.
                    strokeColor: segment.sweep > 0.5 ? segment.color : "transparent"
                    capStyle: ShapePath.FlatCap

                    PathAngleArc {
                        centerX: home.radius
                        centerY: home.radius
                        radiusX: home.radius - 1
                        radiusY: home.radius - 1
                        startAngle: segment.startAngle
                        sweepAngle: segment.sweep
                    }
                }

                RingSegment {
                    startAngle: -90
                    sweep: ring.solarSweep
                    color: root.solarColor
                }
                RingSegment {
                    startAngle: -90 + ring.solarSweep
                    sweep: ring.batterySweep
                    color: root.batteryDischargeColor
                }
                RingSegment {
                    startAngle: -90 + ring.solarSweep + ring.batterySweep
                    sweep: root.homePower > 0 ? ring.gridSweep : 360
                    color: root.homePower > 0 ? root.gridImportColor : root.idleColor
                }
            }

            EnergyNode {
                id: battery
                centerX: 510
                centerY: 260
                labelBelow: true
                label: qsTr("Battery")
                icon: root.batteryIcon(root.batterySoc, root.batteryCharge > 0)
                color: root.batteryCharge > root.batteryDischarge ? root.batteryChargeColor : root.batteryDischargeColor
                clickable: true
                onClicked: root.detailsRequested("battery")

                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: Math.round(root.batterySoc) + " %"
                    font.pixelSize: 11
                }
                FlowValue {
                    icon: "mdi:arrow-down"
                    watts: root.batteryCharge
                    color: root.batteryChargeColor
                }
                FlowValue {
                    icon: "mdi:arrow-up"
                    watts: root.batteryDischarge
                    color: root.batteryDischargeColor
                }
            }

            // Individual consumers, below home. Invisible once faded out, which
            // also stops their lines' dot animations.
            Item {
                id: consumers
                anchors.fill: parent
                opacity: root.consumersVisible ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.InOutQuad
                    }
                }

                // They leave home from its lower sides, clear of its caption.
                readonly property real homeAttachOffset: 28

                EnergyFlowLine {
                    anchors.fill: parent
                    from: root.leftOf(home, consumers.homeAttachOffset)
                    to: root.topOf(ev, 0)
                    control: Qt.point(to.x, from.y)
                    power: root.evPower
                    maxPower: root.maxFlow
                    color: root.evColor
                    idleColor: root.idleColor
                }
                EnergyFlowLine {
                    anchors.fill: parent
                    from: root.rightOf(home, consumers.homeAttachOffset)
                    to: root.topOf(heatPump, 0)
                    control: Qt.point(to.x, from.y)
                    power: root.heatPumpPower
                    maxPower: root.maxFlow
                    color: root.heatPumpColor
                    idleColor: root.idleColor
                }

                EnergyNode {
                    id: ev
                    centerX: 150
                    centerY: 590
                    labelBelow: true
                    label: qsTr("Car")
                    icon: "mdi:car-electric"
                    color: root.evColor

                    FlowValue {
                        watts: root.evPower
                    }
                }

                EnergyNode {
                    id: heatPump
                    centerX: 430
                    centerY: 590
                    labelBelow: true
                    label: qsTr("Heat pump")
                    icon: "mdi:heat-pump"
                    color: root.heatPumpColor

                    FlowValue {
                        watts: root.heatPumpPower
                    }
                }
            }
        }
    }
}
