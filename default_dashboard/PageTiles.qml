import QtQuick
import QtQuick.Controls

import QtHomeAssistant
import 'qrc:/res/QtHomeAssistant/qml/Features'

// Stress test: a wall of Tile{} bound to a handful of real entities, repeated
// to reach `tileCount` live instances. Tune tileCount/entityIds to size the
// test differently -- no rebuild needed, this file loads straight off disk.
Item {
    id: root

    readonly property var entityIds: [
        "switch.home_assistant_voice_09674a_mute",
        "light.swiatla_na_zewnatrz",
        "light.nspanel_office_relay_1"
    ]
    property int tileCount: 60

    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        contentWidth: availableWidth
        clip: true

        Flow {
            width: parent.width
            spacing: 10

            Repeater {
                model: root.tileCount

                Tile {
                    required property int index

                    width: 220
                    height: 90
                    entity_id: root.entityIds[index % root.entityIds.length]
                    features: [
                        ToggleFeature {},
                        LightBrightnessFeature {}
                    ]
                }
            }
        }
    }
}
