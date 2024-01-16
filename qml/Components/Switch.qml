import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Switch {
    id: control
    property string on_icon
    property string off_icon
    indicator: Rectangle {
        implicitWidth: 80
        implicitHeight: 240
        color: control.checked ? Qt.rgba(73 / 255, 61 / 255, 23 / 255, 1) : Qt.rgba(54 / 255, 54 / 255, 54 / 255, 1)
        radius: 15

        anchors.centerIn: parent

        Rectangle {
            width: parent.width - 10
            anchors.horizontalCenter: parent.horizontalCenter
            height: (parent.height / 2) - 10
            radius: parent.radius
            color: control.checked ? Qt.rgba(255 / 255, 193 / 255, 7 / 255, 1) : Qt.rgba(158 / 255, 158 / 255, 158 / 255, 1)

            y: control.checked ? 5 : (parent.height / 2) + 5
            Behavior on y {
                PropertyAnimation {
                }
            }

            Image {
                anchors.centerIn: parent
                source: checked ? on_icon : off_icon
            }
        }
    }
}
