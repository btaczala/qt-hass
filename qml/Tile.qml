import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

import QtHomeAssistant

// A Home Assistant Lovelace tile card: the entity's icon in a state-tinted
// circle, its name and state, and an optional stack of features underneath.
//
//     Tile {
//         entity_id: "switch.kettle"
//         features: [ ToggleFeature {} ]
//     }
//
// Tapping the icon toggles entities that can be toggled; tapping anywhere else
// asks for the entity's details, like Lovelace's more-info.
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

    // list<Item> here, not list<TileFeature>: a list of TileFeature (a
    // composite QML type, not a C++-registered one) makes the Tile type
    // unavailable at all on Android, even though the identical module works
    // fine on desktop. list<Item> keeps the same `features: [A{}, B{}]`
    // declaration syntax and runtime behavior -- JS property assignment on
    // each element still works via its actual TileFeature-derived type.
    property list<Item> features

    // Gap above each stacked feature, and beside an inline one.
    readonly property real featureSpacing: 12

    readonly property string domain: root.entity_id.split(".")[0]
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
    readonly property bool toggleable: ["automation", "fan", "humidifier", "input_boolean", "light", "siren", "switch"].includes(root.domain)

    readonly property color stateColor: root.isActive ? root.activeColor : root.Material.hintTextColor

    readonly property string displayName: root.name || root.attributes.friendly_name || root.entity_id

    // [resting, active] icons for domains Home Assistant draws per state.
    readonly property var domainIcons: ({
        fan: ["mdi:fan-off", "mdi:fan"],
        input_boolean: ["mdi:toggle-switch-off-outline", "mdi:toggle-switch-outline"],
        light: ["mdi:lightbulb-off", "mdi:lightbulb"],
        switch: ["mdi:toggle-switch-variant-off", "mdi:toggle-switch-variant"]
    })
    readonly property string resolvedIcon: root.icon || root.attributes.icon || (root.domainIcons[root.domain]?.[root.isActive ? 1 : 0] ?? "mdi:bookmark")

    readonly property var stateLabels: ({
        on: qsTr("On"),
        off: qsTr("Off"),
        unavailable: qsTr("Unavailable"),
        unknown: qsTr("Unknown")
    })
    readonly property string stateDisplay: {
        if (root.domain === "light" && root.isOn && root.attributes.brightness != null)
            return qsTr("%1%").arg(Math.round(root.attributes.brightness / 2.55));
        const label = root.stateLabels[root.entityState] ?? root.entityState;
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

    function setOn(on) {
        HassAPI.callService(root.domain, on ? "turn_on" : "turn_off", root.entity_id);
    }

    function toggle() {
        root.setOn(!root.isOn);
    }

    function moreInfo() {
        Controler.requestDetails(root.entity_id, root.displayName);
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

    TapHandler {
        onTapped: root.moreInfo()
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

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleable ? root.toggle() : root.moreInfo()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
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
