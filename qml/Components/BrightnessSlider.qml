import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "../Hass.js" as HassAPI
import "../Components" as Components
import ".." as Common
import QtQuick.Dialogs

Slider {
    id: control

    width: 60
    height: 300

    property var sliderColor: Qt.rgba(0.5, 0.5, 0.5, 1)

    property bool colorTemp: false

    orientation: Qt.Vertical
    Layout.preferredWidth: 60
    Layout.alignment: Qt.AlignHCenter
    from: 0
    to: 1
    rotation: 180

    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        implicitWidth: 20
        implicitHeight: parent.height
        width: control.availableWidth
        height: implicitHeight
        radius: 10
        color: Material.background
        // color: "red"

        Rectangle {
            x: 0
            y: 0
            width: parent.width
            height: parent.height - (parent.height * (1 - control.visualPosition))
            radius: parent.radius
            visible: control.enabled && !control.colorTemp
            color: control.sliderColor
        }
        gradient: control.colorTemp ? colorTempGradient : null
    }

    handle: Rectangle {
        color: "black"
        width: control.width * 0.6
        height: 4
        x: control.leftPadding + (control.availableWidth - width - 6)
        y: parent.height - (parent.height * (1 - control.visualPosition)) - control.topPadding
        radius: 4
        visible: control.enabled
    }

    Gradient {
        id: colorTempGradient

        GradientStop {
            position: 0.0
            color: Qt.rgba(255 / 255, 254 / 255, 250 / 255)
        }
        GradientStop {
            position: 1
            color: Qt.rgba(255 / 255, 178 / 255, 111 / 255)
        }
    }
}
