import QtQml
import QtQuick

import QtHomeAssistant

// An alarm_control_panel entity: its state as HA's frontend shows it (label,
// icon, color), the arm modes it supports, and the services to arm and disarm
// it. Shared by AlarmCard and AlarmControls.
HassEntity {
    id: root

    // Colors per kind of state.
    property color disarmedColor: "#2196f3"
    property color armedColor: "#4caf50"
    property color pendingColor: "#ff9800"
    property color triggeredColor: "#f44336"
    property color unavailableColor: "#9e9e9e"

    // Set while a service call is waiting for HA's answer.
    property bool busy: false
    // HA's error for the last failed call, cleared by the next one.
    property string error

    // AlarmControlPanelEntityFeature, and the service and look of each mode.
    readonly property var allModes: [
        {
            feature: 1,
            state: "armed_home",
            service: "alarm_arm_home",
            label: qsTr("Home"),
            icon: "mdi:shield-home"
        },
        {
            feature: 2,
            state: "armed_away",
            service: "alarm_arm_away",
            label: qsTr("Away"),
            icon: "mdi:shield-lock"
        },
        {
            feature: 4,
            state: "armed_night",
            service: "alarm_arm_night",
            label: qsTr("Night"),
            icon: "mdi:shield-moon"
        },
        {
            feature: 32,
            state: "armed_vacation",
            service: "alarm_arm_vacation",
            label: qsTr("Vacation"),
            icon: "mdi:shield-airplane"
        },
        {
            feature: 16,
            state: "armed_custom_bypass",
            service: "alarm_arm_custom_bypass",
            label: qsTr("Custom bypass"),
            icon: "mdi:security"
        }
    ]
    readonly property var modes: root.allModes.filter(m => (root.attributes.supported_features ?? 0) & m.feature)
    // What the plain "Arm" button uses: away when there is one.
    readonly property var defaultMode: root.modes.find(m => m.state === "armed_away") ?? root.modes[0] ?? null

    // null, "number" or "text".
    readonly property var codeFormat: root.attributes.code_format ?? null
    readonly property bool codeArmRequired: root.codeFormat !== null && (root.attributes.code_arm_required ?? true)

    readonly property bool disarmed: root.state === "disarmed"
    readonly property bool triggered: root.state === "triggered"
    readonly property bool pending: ["arming", "pending", "disarming"].includes(root.state)
    readonly property bool armed: root.state.startsWith("armed_")

    readonly property string stateLabel: {
        switch (root.state) {
        case "disarmed":
            return qsTr("Disarmed");
        case "armed_home":
            return qsTr("Armed home");
        case "armed_away":
            return qsTr("Armed away");
        case "armed_night":
            return qsTr("Armed night");
        case "armed_vacation":
            return qsTr("Armed vacation");
        case "armed_custom_bypass":
            return qsTr("Armed custom bypass");
        case "arming":
            return qsTr("Arming");
        case "disarming":
            return qsTr("Disarming");
        case "pending":
            return qsTr("Pending");
        case "triggered":
            return qsTr("Triggered");
        case "":
        case "unknown":
            return qsTr("Unknown");
        case "unavailable":
            return qsTr("Unavailable");
        default:
            return root.state;
        }
    }
    readonly property string icon: {
        if (root.disarmed)
            return "mdi:shield-off";
        if (root.triggered)
            return "mdi:bell-ring";
        if (root.pending)
            return "mdi:shield-sync";
        return root.allModes.find(m => m.state === root.state)?.icon ?? (root.available ? "mdi:shield" : "mdi:shield-off-outline");
    }
    readonly property color color: !root.available ? root.unavailableColor : root.disarmed ? root.disarmedColor : root.triggered ? root.triggeredColor : root.pending ? root.pendingColor : root.armedColor

    // `code` may be empty; it's only sent when given.
    function call(service: string, code: string) {
        root.busy = true;
        root.error = "";
        const sent = HassAPI.command("call_service", {
            domain: "alarm_control_panel",
            service: service,
            target: {
                entity_id: root.entityId
            },
            service_data: code !== "" ? {
                code: code
            } : {}
        }, root, (ok, json, message) => {
            root.busy = false;
            if (!ok)
                root.error = message || qsTr("Home Assistant refused the request.");
        });
        if (!sent) {
            root.busy = false;
            root.error = qsTr("Not connected to Home Assistant.");
        }
    }

    function arm(mode: var, code: string) {
        root.call(mode.service, code);
    }

    function disarm(code: string) {
        root.call("alarm_disarm", code);
    }
}
