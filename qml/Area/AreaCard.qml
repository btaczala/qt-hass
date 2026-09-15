pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls.Material

import QtHomeAssistant
import "../Cameras/CameraUrls.js" as CameraUrls

// A Home Assistant Lovelace area card: a header with the area's picture (or
// its icon), its name and a line of sensors, over tiles for the entities it
// controls. It shows exactly the entities it's given, never others from the
// area:
//
//     AreaCard {
//         areaId: "living_room"
//         sensors: ["sensor.living_room_temperature", "binary_sensor.living_room_motion"]
//         controls: [
//             { entityId: "light.living_room", tapAction: "toggle" },
//             { entityId: "climate.living_room", name: "AC", icon: "mdi:air-conditioner" }
//         ]
//     }
//
// A sensor is an entity id, or { entityId, icon }. A control is an entity id,
// or { entityId, name, icon, iconOnly, tapAction, holdAction }: its Tile runs
// tapAction on a tap anywhere, the icon included -- "more-info" (the default)
// or "toggle" -- and holdAction ("none" by default) on a hold. name replaces
// the entity's friendly name; iconOnly controls drop the name and state and
// sit in a row of icons above the other tiles.
Pane {
    id: root

    // The area's id in Home Assistant, e.g. "living_room". Its name, icon and
    // picture come from the area registry.
    required property string areaId
    // Empty means the area's own name and icon.
    property string name
    property string icon
    // What the header shows: "picture", the area's picture; "icon", the
    // area's icon; "url", the image at pictureUrl -- a full URL, or a path on
    // the Home Assistant server such as "/local/rooms/office.jpg". The icon
    // stands in while a picture loads or when there is none.
    property string displayType: "picture"
    property string pictureUrl

    property var sensors: []
    property var controls: []

    property real headerHeight: 160
    // Tiles are laid out in as many columns of at least this width as fit.
    property real minControlWidth: 170

    // This area's entry in the area registry; empty until read.
    property var area: ({})

    readonly property string displayName: root.name || root.area.name || root.areaId
    // Only MDI icons render; an area's icon from another set (e.g. "phu:") doesn't.
    readonly property string resolvedIcon: root.icon || (root.area.icon?.startsWith("mdi:") ? root.area.icon : "mdi:texture-box")
    readonly property string picturePath: root.displayType === "url" ? root.pictureUrl : root.displayType === "picture" ? root.area.picture ?? "" : ""
    readonly property bool hasPicture: picture.status === Image.Ready
    readonly property color headerForeground: root.hasPicture ? "white" : root.Material.foreground
    // Shaders don't run under the software renderer; corners stay square there.
    readonly property bool roundCorners: root.GraphicsInfo.api !== GraphicsInfo.Software
    readonly property real cornerRadius: root.Material.roundedScale

    function loadArea() {
        HassAPI.command("config/area_registry/list", {}, root, (ok, json, error) => {
            if (!ok) {
                console.warn(`AreaCard: couldn't read the area registry: ${error}`);
                return;
            }
            const area = JSON.parse(json).find(a => a.area_id === root.areaId);
            if (!area)
                console.warn(`AreaCard: no area "${root.areaId}"`);
            root.area = area ?? {};
        });
    }

    // Controls by kind, each in the order given: icon-only ones in a row
    // above the tiles.
    readonly property var iconControls: root.controls.map(root.entry).filter(c => c.iconOnly)
    readonly property var tileControls: root.controls.map(root.entry).filter(c => !c.iconOnly)
    // Flat and tinted: a card inside a card.
    readonly property color tileBackground: Qt.tint(root.Material.background, Qt.rgba(root.Material.foreground.r, root.Material.foreground.g, root.Material.foreground.b, 0.06))

    // A control's Tile. Inline components don't see this file's ids, so
    // everything comes in through its properties.
    component AreaTile: Tile {
        id: tile

        required property var config
        property color tint

        entityId: tile.config.entityId
        name: tile.config.name ?? ""
        icon: tile.config.icon ?? ""
        iconOnly: tile.config.iconOnly ?? false
        tapAction: tile.config.tapAction ?? "more-info"
        iconTapAction: tile.tapAction
        holdAction: tile.config.holdAction ?? "none"
        Material.elevation: 0
        Material.background: tile.tint
    }

    function entry(config) {
        return typeof config === "string" ? {
            entityId: config
        } : config;
    }

    implicitWidth: 360
    padding: 0
    Material.elevation: 4
    Material.roundedScale: Material.MediumScale

    onAreaIdChanged: root.loadArea()
    Component.onCompleted: root.loadArea()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            id: header

            Layout.fillWidth: true
            Layout.preferredHeight: root.headerHeight

            layer.enabled: root.roundCorners
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: headerMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }

            // The card's rounded top; its bottom corners too when nothing is below.
            Item {
                id: headerMask
                width: header.width
                height: header.height
                layer.enabled: true
                visible: false
                clip: true

                Rectangle {
                    width: parent.width
                    height: parent.height + (controlsArea.visible ? root.cornerRadius : 0)
                    radius: root.cornerRadius
                }
            }

            Rectangle {
                anchors.fill: parent
                visible: !root.hasPicture
                color: Qt.rgba(root.Material.accentColor.r, root.Material.accentColor.g, root.Material.accentColor.b, 0.15)

                MdiIcon {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 16
                    icon: root.resolvedIcon
                    iconSize: Math.min(parent.height - 32, 96)
                    color: root.Material.accentColor
                }
            }

            Image {
                id: picture
                anchors.fill: parent
                visible: root.hasPicture
                source: root.picturePath.startsWith("/") ? CameraUrls.resolve(Controler.hassUrl, root.picturePath) : root.picturePath
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                onStatusChanged: if (picture.status === Image.Error)
                    console.warn(`AreaCard: couldn't load ${picture.source}`)
            }

            // Keeps white text readable on any picture.
            Rectangle {
                anchors.fill: parent
                visible: root.hasPicture
                gradient: Gradient {
                    GradientStop {
                        position: 0.3
                        color: "transparent"
                    }
                    GradientStop {
                        position: 1
                        color: Qt.rgba(0, 0, 0, 0.75)
                    }
                }
            }

            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 16
                spacing: 4

                Label {
                    Layout.fillWidth: true
                    text: root.displayName
                    font.pixelSize: 22
                    font.weight: Font.Medium
                    color: root.headerForeground
                    elide: Text.ElideRight
                }

                Flow {
                    Layout.fillWidth: true
                    visible: root.sensors.length > 0
                    spacing: 12

                    Repeater {
                        model: root.sensors

                        AreaSensor {
                            required property var modelData
                            entityId: root.entry(modelData).entityId
                            icon: root.entry(modelData).icon ?? ""
                            color: root.headerForeground
                        }
                    }
                }
            }
        }

        ColumnLayout {
            id: controlsArea

            Layout.fillWidth: true
            Layout.margins: 12
            visible: root.controls.length > 0
            spacing: 8

            Flow {
                Layout.fillWidth: true
                visible: root.iconControls.length > 0
                spacing: 8

                Repeater {
                    model: root.iconControls

                    AreaTile {
                        required property var modelData
                        config: modelData
                        tint: root.tileBackground
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                visible: root.tileControls.length > 0
                columns: Math.max(1, Math.floor((controlsArea.width + columnSpacing) / (root.minControlWidth + columnSpacing)))
                columnSpacing: 8
                rowSpacing: 8
                uniformCellWidths: true

                Repeater {
                    model: root.tileControls

                    AreaTile {
                        required property var modelData
                        Layout.fillWidth: true
                        config: modelData
                        tint: root.tileBackground
                    }
                }
            }
        }
    }
}
