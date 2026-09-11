import QtQuick
import QtQuick.Controls

import QtHomeAssistant

// Stress test: a wall of Light{} bound to a handful of real entities, repeated
// to reach `lightCount` live instances. Tune lightCount/entityIds to size the
// test differently -- no rebuild needed, this file loads straight off disk.
Item {
    id: root

    readonly property var entityIds: [
        "light.swiatla_na_zewnatrz",
        "light.nspanel_office_relay_1"
    ]
    property int lightCount: 40

    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        contentWidth: availableWidth
        clip: true

        Flow {
            width: parent.width
            spacing: 10

            Repeater {
                model: root.lightCount

                Light {
                    required property int index

                    width: 140
                    height: 140
                    entity_id: root.entityIds[index % root.entityIds.length]
                }
            }
        }
    }
}
