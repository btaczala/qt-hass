import QtQml

import QtHomeAssistant

// One Home Assistant entity's live state, for code that needs the data rather
// than a card (EntityBase): state, attributes, and the state as a number.
// `entityId` may change, or start empty (nothing is read until it's set).
QtObject {
    id: root

    required property string entityId

    property string state
    property var attributes: ({})
    // When the state last changed, in ms since the epoch; NaN until known.
    property real lastChanged: NaN
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
        root.lastChanged = entity.last_changed ? entity.last_changed * 1000 : NaN;
    }

    // The id the handler is registered under, if any.
    property string registeredId
    property bool completed: false

    function track() {
        if (root.registeredId === root.entityId)
            return;
        if (root.registeredId !== "")
            HassAPI.unregisterStateChanges(root.registeredId, root.handler);
        root.state = "";
        root.attributes = {};
        root.lastChanged = NaN;
        root.registeredId = root.entityId;
        if (root.entityId !== "")
            HassAPI.registerStateChanges(root.entityId, root.handler);
    }

    onEntityIdChanged: if (root.completed)
        root.track()
    Component.onCompleted: {
        root.completed = true;
        root.track();
    }
    Component.onDestruction: if (root.registeredId !== "")
        HassAPI.unregisterStateChanges(root.registeredId, root.handler)
}
