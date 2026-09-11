import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

import QtHomeAssistant

Pane {
    id: root
    required property string entity_id

    width: 10
    height: 10

    property var update
    property var entity_data

    Material.elevation: 4
    Material.roundedScale: Material.SmallScale

    Component.onCompleted: {
        HassAPI.registerStateChanges(root.entity_id, root.update)
    }

    // Without this, a destroyed card (e.g. a StackView page switch) leaves
    // its callback registered forever -- the next state update for this
    // entity then calls into a deleted object.
    Component.onDestruction: {
        HassAPI.unregisterStateChanges(root.entity_id, root.update)
    }
}
