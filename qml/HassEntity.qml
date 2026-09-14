import QtQml

import QtHomeAssistant

// One Home Assistant entity's live state, for code that needs the data rather
// than a card (EntityBase): state, attributes, and the state as a number.
QtObject {
    id: root

    required property string entityId

    property string state
    property var attributes: ({})
    readonly property bool available: root.state !== "" && root.state !== "unknown" && root.state !== "unavailable"
    // NaN unless the state is numeric.
    readonly property real value: root.available ? Number(root.state) : NaN
    // `value` converted from kW/kWh/MW to W/Wh; other units are left as is.
    readonly property real baseValue: {
        const unit = root.attributes.unit_of_measurement ?? "";
        if (unit.startsWith("k"))
            return root.value * 1000;
        if (unit.startsWith("M"))
            return root.value * 1000000;
        return root.value;
    }

    // A stored function, not a method: unregisterStateChanges() finds the
    // callback by identity, so it has to be the same object both times.
    readonly property var handler: json => {
        const entity = JSON.parse(json);
        root.state = entity.state;
        root.attributes = entity.attributes ?? {};
    }

    Component.onCompleted: HassAPI.registerStateChanges(root.entityId, root.handler)
    Component.onDestruction: HassAPI.unregisterStateChanges(root.entityId, root.handler)
}
