import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

import QtHomeAssistant
import 'qrc:/res/QtHomeAssistant/qml/Cards'
import 'qrc:/res/QtHomeAssistant/qml/Features'

Item {
    RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 5
        Weather {
            Layout.preferredWidth: 200
            Layout.preferredHeight: 200
            entity_id: 'weather.forecast_home'
        }
        Light {
            Layout.preferredWidth: 200
            Layout.preferredHeight: 200
            entity_id: "light.nspanel_office_relay_1"
        }
        Light {
            Layout.preferredWidth: 200
            Layout.preferredHeight: 200
            entity_id: "light.swiatla_na_zewnatrz"
        }
        ColumnLayout {
            Layout.preferredWidth: 250
            Layout.alignment: Qt.AlignTop
            spacing: 5
            Tile {
                Layout.fillWidth: true
                entity_id: "switch.home_assistant_voice_09674a_mute"
                features: [
                    ToggleFeature {},
                    LightBrightnessFeature {}
                ]
            }
            Tile {
                Layout.fillWidth: true
                entity_id: "light.swiatla_na_zewnatrz"
                features: [
                    ToggleFeature {},
                    LightBrightnessFeature {}
                ]
            }
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
