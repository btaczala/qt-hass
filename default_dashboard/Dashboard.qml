import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

import QtHomeAssistant

Item {

    Material.theme: Material.Dark

    GridLayout {
        columns: 3
        anchors.fill: parent
        anchors.margins: 20
        Light {
            Layout.preferredWidth: 200
            Layout.preferredHeight: 200
            entity_id: "light.nspanel_office_relay_1"
        }
        Light {
            Layout.preferredWidth: 200
            Layout.preferredHeight: 200
            entity_id: "light.nspanel_office_relay_1"
        }
        Light {
            Layout.preferredWidth: 200
            Layout.preferredHeight: 200
            entity_id: "light.nspanel_office_relay_1"
        }
    }

    Component.onCompleted: console.log(Material.theme)
}
