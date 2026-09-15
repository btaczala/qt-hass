import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

import QtHomeAssistant
import "Dashboard/DashboardNavigation.js" as DashboardNavigation

// A Home Assistant Lovelace tile card: the entity's icon in a state-tinted
// circle, its name and state, and an optional stack of features underneath.
//
//     Tile {
//         entityId: "switch.kettle"
//         features: [ ToggleFeature {} ]
//     }
//
// Tapping and holding run actions, as Lovelace's tap_action/hold_action do.
// Each is an action name ("more-info", "toggle", "none"), an object
// ({ action: "more-info", entity: "sensor.other" }, or
// { action: "navigate", page: "LivingRoom.qml" } for a page of the dashboard
// with that source, see Dashboard.showPage) or a function:
//
//     Tile {
//         entityId: "light.desk"
//         tapAction: "toggle"
//         holdAction: "more-info"
//         iconTapAction: () => HassAPI.callService("script", "turn_on", "script.desk_scene")
//     }
//
// By default tapping the icon toggles entities that can be toggled, tapping
// anywhere else opens the entity's details in the global details overlay
// (Controler.requestDetails), and holding does nothing.
//
// The implicit height fits every supported feature stacked below the header.
// Given less height than that, the tile switches to Lovelace's inline layout:
// the first supported feature moves into the header row and the rest hide.
EntityBase {
    id: root

    // Lovelace tile options; empty means "use what Home Assistant reports".
    property string name
    property string icon
    property color activeColor: "#ffc107"
    property bool vertical: false
    property bool hideState: false
    // Just the icon: no name or state beside it.
    property bool iconOnly: false

    // Actions, see above. The icon's own actions fall back to these when unset:
    // iconTapAction to toggling (or more-info when the entity can't toggle),
    // iconHoldAction to holdAction.
    property var tapAction: "more-info"
    property var holdAction: "none"
    property var iconTapAction
    property var iconHoldAction

    // list<Item> here, not list<TileFeature>: a list of TileFeature (a
    // composite QML type, not a C++-registered one) makes the Tile type
    // unavailable at all on Android, even though the identical module works
    // fine on desktop. list<Item> keeps the same `features: [A{}, B{}]`
    // declaration syntax and runtime behavior -- JS property assignment on
    // each element still works via its actual TileFeature-derived type.
    property list<Item> features

    // Gap above each stacked feature, and beside an inline one.
    readonly property real featureSpacing: 12

    readonly property string domain: root.entityId.split(".")[0]
    readonly property var attributes: root.entity_data?.attributes ?? ({})
    // Not `state`: that is Item's own property, the one that drives `states`.
    readonly property string entityState: root.entity_data?.state ?? "unknown"

    // The state a domain rests in when that is not plain "off".
    readonly property var restingStates: ({
        alarm_control_panel: "disarmed",
        cover: "closed",
        device_tracker: "not_home",
        lock: "locked",
        media_player: "standby",
        person: "not_home",
        timer: "idle",
        vacuum: "docked",
        valve: "closed"
    })

    readonly property bool isOn: root.entityState === "on"
    readonly property bool isUnavailable: root.entityState === "unavailable"
    readonly property bool isActive: !["off", "unavailable", "unknown", root.restingStates[root.domain]].includes(root.entityState)
    // Climate entities turn on and off only with TURN_ON (128) and TURN_OFF (256) set.
    readonly property bool toggleable: ["automation", "fan", "humidifier", "input_boolean", "light", "lock", "siren", "switch"].includes(root.domain) || root.domain === "climate" && (root.attributes.supported_features & 384) === 384

    // [resting, active] services for domains that do not toggle with
    // turn_off/turn_on.
    readonly property var toggleServices: ({
        lock: ["lock", "unlock"]
    })

    // Writable, like stateDisplay, so a tile can be tinted by its own rule,
    // e.g. a template-card-style color that depends on the state.
    property color stateColor: root.isActive ? root.activeColor : root.Material.hintTextColor

    readonly property string displayName: root.name || root.attributes.friendly_name || root.entityId

    // [resting, active] icons for domains Home Assistant draws per state.
    readonly property var domainIcons: ({
        alarm_control_panel: ["mdi:shield-off", "mdi:shield-lock"],
        cover: ["mdi:window-shutter", "mdi:window-shutter-open"],
        fan: ["mdi:fan-off", "mdi:fan"],
        input_boolean: ["mdi:toggle-switch-off-outline", "mdi:toggle-switch-outline"],
        light: ["mdi:lightbulb-off", "mdi:lightbulb"],
        lock: ["mdi:lock", "mdi:lock-open-variant"],
        media_player: ["mdi:cast", "mdi:cast-connected"],
        switch: ["mdi:toggle-switch-variant-off", "mdi:toggle-switch-variant"]
    })
    // One icon for any state; not in domainIcons, whose pairs ToggleFeature
    // draws on its off and on sides.
    readonly property var singleDomainIcons: ({
        climate: "mdi:thermostat",
        lawn_mower: "mdi:robot-mower"
    })
    // Only MDI icons draw: an entity's icon from another set (e.g. "phu:")
    // falls back to the domain's.
    readonly property string entityIcon: {
        const icon = root.attributes.icon ?? "";
        return !icon.includes(":") || icon.startsWith("mdi:") ? icon : "";
    }
    readonly property string resolvedIcon: root.icon || root.entityIcon || (root.domainIcons[root.domain]?.[root.isActive ? 1 : 0] ?? root.singleDomainIcons[root.domain] ?? "mdi:bookmark")

    readonly property var stateLabels: ({
        on: qsTr("On"),
        off: qsTr("Off"),
        unavailable: qsTr("Unavailable"),
        unknown: qsTr("Unknown")
    })
    // Writable, so a tile can show its own text in place of the state.
    property string stateDisplay: {
        if (root.domain === "light" && root.isOn && root.attributes.brightness != null)
            return qsTr("%1%").arg(Math.round(root.attributes.brightness / 2.55));
        // Other raw states read like HA's: "armed_home" as "Armed home".
        const raw = root.entityState.replace(/_/g, " ");
        const label = root.stateLabels[root.entityState] ?? raw.charAt(0).toUpperCase() + raw.slice(1);
        const unit = root.attributes.unit_of_measurement;
        return unit ? qsTr("%1 %2").arg(label).arg(unit) : label;
    }

    // Height every supported feature needs stacked below the header. It must
    // not depend on the inline layout: height defaults to implicitHeight, so a
    // layout-dependent value here would lock a tile into inline mode or make
    // it flip back and forth. Hence featureSpacing, not each Layout.topMargin.
    readonly property real featuresHeight: {
        let height = 0;
        for (let i = 0; i < root.features.length; ++i) {
            if (root.features[i].supported)
                height += root.featureSpacing + root.features[i].implicitHeight;
        }
        return height;
    }

    // The 1px slack absorbs layouts rounding a fractional implicit height down.
    readonly property bool inlineFeatures: !root.vertical && root.height < root.implicitHeight - 1
    readonly property Item inlineFeature: {
        if (!root.inlineFeatures)
            return null;
        for (let i = 0; i < root.features.length; ++i) {
            if (root.features[i].supported)
                return root.features[i];
        }
        return null;
    }

    // False until every feature knows its tile: assigning `tile` changes
    // `supported`, which must not re-enter placeFeatures() halfway through.
    property bool featuresReady: false

    // `on` means the active state: for a lock, unlocked.
    function setOn(on) {
        const services = root.toggleServices[root.domain] ?? ["turn_off", "turn_on"];
        HassAPI.callService(root.domain, services[on ? 1 : 0], root.entityId);
    }

    function toggle() {
        root.setOn(!root.isActive);
    }

    // Opens the global details overlay; for another entity when given one.
    function moreInfo(entityId) {
        if (entityId && entityId !== root.entityId)
            Controler.requestDetails(entityId, "");
        else
            Controler.requestDetails(root.entityId, root.displayName);
    }

    function performAction(action) {
        if (typeof action === "function") {
            action();
            return;
        }
        const config = typeof action === "string" ? {
            action: action
        } : action ?? {
            action: "none"
        };
        switch (config.action) {
        case "more-info":
            root.moreInfo(config.entity);
            break;
        case "toggle":
            if (!root.toggleable)
                console.warn(`Tile: ${root.entityId} can't be toggled`);
            else if (!root.isUnavailable)
                root.toggle();
            break;
        case "navigate":
            DashboardNavigation.navigate(root, config.page);
            break;
        case "none":
            break;
        default:
            console.warn(`Tile: unknown action "${config.action}" for ${root.entityId}`);
        }
    }

    function isOnIcon(position) {
        return iconCircle.contains(iconCircle.mapFromItem(root, position));
    }

    function placeFeatures() {
        const targets = [];
        let moved = false;
        for (let i = 0; i < root.features.length; ++i) {
            targets.push(root.features[i] === root.inlineFeature ? topRow : content);
            moved = moved || root.features[i].parent !== targets[i];
        }
        if (!moved)
            return;

        // Re-append all of them in declaration order: a feature returning from
        // the header row would otherwise land after the others.
        for (let i = 0; i < root.features.length; ++i) {
            root.features[i].parent = null;
            root.features[i].parent = targets[i];
        }
    }

    update: function (response) {
        root.entity_data = JSON.parse(response);
    }

    width: implicitWidth
    height: implicitHeight
    contentWidth: header.implicitWidth
    contentHeight: header.implicitHeight + root.featuresHeight
    Material.roundedScale: Material.MediumScale

    onInlineFeatureChanged: {
        if (root.featuresReady)
            root.placeFeatures();
    }

    // One handler for the whole card, the icon included: nested TapHandlers
    // only grab passively, so one on the icon would fire along with this one.
    // Feature controls take the press themselves and never reach it. A hold
    // past the threshold emits longPressed and no tapped.
    TapHandler {
        id: tapHandler
        longPressThreshold: 0.5
        onTapped: eventPoint => {
            if (root.isOnIcon(eventPoint.pressPosition))
                root.performAction(root.iconTapAction !== undefined ? root.iconTapAction : root.toggleable ? "toggle" : "more-info");
            else
                root.performAction(root.tapAction);
        }
        onLongPressed: {
            if (root.isOnIcon(tapHandler.point.pressPosition) && root.iconHoldAction !== undefined)
                root.performAction(root.iconHoldAction);
            else
                root.performAction(root.holdAction);
        }
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        spacing: 0

        RowLayout {
            id: topRow
            Layout.fillWidth: true
            spacing: root.featureSpacing

            GridLayout {
                id: header
                Layout.fillWidth: true
                columns: root.vertical ? 1 : 2
                columnSpacing: 10
                rowSpacing: 6

                Rectangle {
                    id: iconCircle
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignCenter
                    radius: 20
                    color: Qt.rgba(root.stateColor.r, root.stateColor.g, root.stateColor.b, 0.2)

                    MdiIcon {
                        anchors.centerIn: parent
                        icon: root.resolvedIcon
                        color: root.stateColor
                    }

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: !root.iconOnly
                    spacing: 0

                    Label {
                        Layout.fillWidth: true
                        text: root.displayName
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        horizontalAlignment: root.vertical ? Text.AlignHCenter : Text.AlignLeft
                    }

                    Label {
                        Layout.fillWidth: true
                        visible: !root.hideState
                        text: root.stateDisplay
                        font.pixelSize: 12
                        color: root.Material.secondaryTextColor
                        elide: Text.ElideRight
                        horizontalAlignment: root.vertical ? Text.AlignHCenter : Text.AlignLeft
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        for (let i = 0; i < root.features.length; ++i)
            root.features[i].tile = root;
        root.featuresReady = true;
        root.placeFeatures();
    }
}
