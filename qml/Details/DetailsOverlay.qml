pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

import QtHomeAssistant

// The app's one entity details view, like Lovelace's more-info dialog. Anything
// can open it with Controler.requestDetails(entityId, name) -- a Tile's
// "more-info" action does -- and a new request while it's open shows that
// entity instead. It shows the entity as a tile with the controls its domain
// supports (toggle, brightness), or an alarm panel's AlarmControls; when its
// state last changed; a sensor's history (SensorHistory, BinarySensorHistory);
// and its attributes. Lives in Main.qml, outside the dashboard, so dashboards
// only request it.
Popup {
    id: root

    property string entityId
    // Display name; the entity's friendly name when empty.
    property string name

    // For the "ago" text; ticks while open.
    property real now: Date.now()
    // Content may ask for more room, e.g. an alarm keypad beside its buttons;
    // back to 480 for each new entity.
    property real preferredWidth: 480
    readonly property bool isAlarm: root.entityId.startsWith("alarm_control_panel.")

    function show(entityId: string, name: string) {
        // Through "" so the content is created again: an entity card only
        // registers the entity it was created with.
        root.entityId = "";
        root.preferredWidth = 480;
        root.name = name;
        root.entityId = entityId;
        root.now = Date.now();
        root.open();
    }

    function ago(ms: real): string {
        const minutes = Math.floor((root.now - ms) / 60000);
        if (isNaN(minutes))
            return "";
        if (minutes < 1)
            return qsTr("just now");
        if (minutes < 60)
            return qsTr("%1 min ago").arg(minutes);
        if (minutes < 24 * 60)
            return qsTr("%1 h ago").arg(Math.floor(minutes / 60));
        return new Date(ms).toLocaleString(Qt.locale(), "d MMM HH:mm");
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(parent ? parent.width - 32 : 0, root.preferredWidth)
    height: Math.min(parent ? parent.height - 32 : 0, implicitHeight)
    padding: 20
    topPadding: 8
    modal: true
    // For CloseOnEscape, which is also Android's back button.
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    // Plain rather than Material's elevated one, so it's solid everywhere,
    // including under the software renderer.
    background: Rectangle {
        color: root.Material.dialogColor
        radius: 12
    }

    onClosed: root.entityId = ""

    Timer {
        interval: 30000
        repeat: true
        running: root.visible
        onTriggered: root.now = Date.now()
    }

    Connections {
        target: Controler
        function onRequestDetails(entity_id: string, friendly_name: string) {
            root.show(entity_id, friendly_name);
        }
        // Popups draw above the screensaver, so don't stay open under it.
        function onScreensaverActiveChanged() {
            if (Controler.screensaverActive)
                root.close();
        }
    }

    // Its entities' subscriptions end with the connection.
    Connections {
        target: HassAPI
        function onConnectedChanged() {
            if (!HassAPI.connected)
                root.close();
        }
    }

    contentItem: Loader {
        active: root.visible && root.entityId !== ""

        sourceComponent: ColumnLayout {
            spacing: 8

            HassEntity {
                id: entity
                entityId: root.entityId
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Label {
                    Layout.fillWidth: true
                    text: root.entityId
                    font.pixelSize: 12
                    color: root.Material.hintTextColor
                    elide: Text.ElideMiddle
                }
                ToolButton {
                    contentItem: MdiIcon {
                        icon: "mdi:close"
                    }
                    Accessible.name: qsTr("Close")
                    onClicked: root.close()
                }
            }

            // Tapping it here would only open this again. Alarm controls
            // show the state themselves.
            Tile {
                Layout.fillWidth: true
                visible: !root.isAlarm
                entityId: root.entityId
                name: root.name
                tapAction: "none"
                iconTapAction: "none"
                background: null
                padding: 0
                features: [
                    ToggleFeature {},
                    LightBrightnessFeature {}
                ]
            }

            Label {
                Layout.fillWidth: true
                visible: !isNaN(entity.lastChanged)
                text: qsTr("Changed %1").arg(root.ago(entity.lastChanged))
                font.pixelSize: 12
                color: root.Material.secondaryTextColor
            }

            // Alarm panels: arming and disarming.
            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                active: root.isAlarm
                visible: active
                sourceComponent: AlarmControls {
                    id: alarmControls
                    entityId: root.entityId

                    // Not restored when destroyed: show() resets it.
                    Binding {
                        target: root
                        property: "preferredWidth"
                        value: alarmControls.preferredWidth
                    }
                }
            }

            // Numeric sensors: their value over time.
            Loader {
                Layout.fillWidth: true
                Layout.topMargin: 8
                active: root.entityId.startsWith("sensor.") && (entity.attributes.unit_of_measurement !== undefined || entity.attributes.state_class !== undefined || !isNaN(entity.value))
                visible: active
                sourceComponent: SensorHistory {
                    entityId: root.entityId
                }
            }

            // Binary sensors: how long they were on, per hour.
            Loader {
                Layout.fillWidth: true
                Layout.topMargin: 8
                active: root.entityId.startsWith("binary_sensor.")
                visible: active
                sourceComponent: BinarySensorHistory {
                    entityId: root.entityId
                }
            }

            DetailsAttributes {
                Layout.fillWidth: true
                visible: count > 0
                Layout.fillHeight: true
                Layout.topMargin: 8
                attributes: entity.attributes
            }
        }
    }
}
