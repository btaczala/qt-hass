import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

import QtHomeAssistant
import 'qrc:/res/QtHomeAssistant/qml/Cards'

Item {
    Material.theme: Material.Dark
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
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
