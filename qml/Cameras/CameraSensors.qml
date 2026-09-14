pragma ComponentBehavior: Bound

import QtQml

import QtHomeAssistant

// What a camera knows about its scene: whether it sees motion, whether it's
// dark, and when motion was last detected. The entities are found on the
// camera's device (config/entity_registry/get, then search/related), matched
// by name the way UniFi Protect names them -- binary_sensor.<camera>_motion,
// binary_sensor.<camera>_is_dark, event.<...>_motion_detection -- unless given
// explicitly. Whatever isn't found stays unknown.
QtObject {
    id: root

    required property string cameraEntity
    // Explicit entities; empty ones are discovered.
    property string motionEntity
    property string darkEntity
    property string lastMotionEntity

    property var discovered: ({})

    readonly property bool hasMotion: motion.available
    readonly property bool motionDetected: motion.state === "on"
    readonly property bool hasDark: dark.available
    readonly property bool isDark: dark.state === "on"
    // ms since the epoch; NaN when unknown. The motion event's timestamp
    // when there is one, else when the motion sensor last turned off.
    readonly property real lastMotion: {
        const event = Date.parse(lastMotionEvent.state);
        if (!isNaN(event))
            return event;
        return root.hasMotion && !root.motionDetected ? motion.lastChanged : NaN;
    }
    readonly property bool hasAny: root.hasMotion || root.hasDark || !isNaN(root.lastMotion)

    function discover() {
        HassAPI.command("config/entity_registry/get", {
            entity_id: root.cameraEntity
        }, root, (ok, json) => {
            const deviceId = ok ? JSON.parse(json)?.device_id : null;
            if (!deviceId)
                return;
            HassAPI.command("search/related", {
                item_type: "device",
                item_id: deviceId
            }, root, (ok2, json2) => {
                const entities = ok2 ? JSON.parse(json2)?.entity ?? [] : [];
                // "_detections_motion" is a setting (whether motion is
                // detected at all), not a reading. Of several matches the
                // shortest, e.g. "_motion" over a numbered "_motion_2".
                const find = (domain, pattern) => entities.filter(e => e.startsWith(domain + ".") && pattern.test(e) && !e.includes("_detections_")).sort((a, b) => a.length - b.length)[0] ?? "";
                root.discovered = {
                    motion: find("binary_sensor", /_motion(_\d+)?$/),
                    dark: find("binary_sensor", /_is_dark(_\d+)?$/),
                    lastMotion: find("event", /_motion_detection(_\d+)?$/)
                };
            });
        });
    }

    readonly property HassEntity motion: HassEntity {
        entityId: root.motionEntity || (root.discovered.motion ?? "")
    }
    readonly property HassEntity dark: HassEntity {
        entityId: root.darkEntity || (root.discovered.dark ?? "")
    }
    readonly property HassEntity lastMotionEvent: HassEntity {
        entityId: root.lastMotionEntity || (root.discovered.lastMotion ?? "")
    }

    Component.onCompleted: if (!root.motionEntity || !root.darkEntity || !root.lastMotionEntity)
        root.discover()
}
