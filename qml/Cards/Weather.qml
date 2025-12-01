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



    RowLayout {
        anchors.fill: parent
        Image {
            source: `https://raw.githubusercontent.com/Templarian/MaterialDesign/refs/heads/master/svg/weather-${root.state}.svg` 
        }
    }
}
