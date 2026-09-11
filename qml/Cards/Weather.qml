import QtQuick
import QtQuick.Layouts

import QtHomeAssistant

EntityBase {
    id: root

    property string state: "dust"

    update: function (response) {
        var j = JSON.parse(response);
        console.log('weather.qml', JSON.stringify(j.state))
        root.state = j.state
    }



    // Most Home Assistant weather states concatenate straight into an MDI name,
    // but three do not -- and those silently rendered nothing before.
    readonly property var iconOverrides: ({
        "clear-night": "mdi:weather-night",
        "partlycloudy": "mdi:weather-partly-cloudy",
        "exceptional": "mdi:weather-cloudy-alert"
    })

    RowLayout {
        anchors.fill: parent
        MdiIcon {
            Layout.alignment: Qt.AlignCenter
            iconSize: 64
            icon: root.iconOverrides[root.state] ?? `mdi:weather-${root.state}`
        }
    }
}
