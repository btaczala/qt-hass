import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

import QtHomeAssistant
import HassAPI

Rectangle {
    color: "Green"

    Component.onCompleted:{
        console.log(controller)
        console.log(HassAPI.light_toggle(''))
    }

    Light {
        entity: "test123"
    }
}

