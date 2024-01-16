import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    width: 480
    height: 480
    function addZero(i) {
        if (i < 10) {
            i = "0" + i;
        }
        return i;
    }

    property var currentDate: new Date()

    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 2 / 3
        height: parent.height * 2 / 3
        color: "grey"
        radius: 40
        opacity: 0.5

        ColumnLayout {
            // anchors.fill: parent
            anchors.centerIn: parent
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: currentDate.getHours() + ":" + currentDate.getMinutes() + ":" + addZero(currentDate.getSeconds())
                font.pixelSize: 52
                color: "white"
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: currentDate.toLocaleDateString()
                font.pixelSize: 22
                color: "white"
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.currentDate = new Date();
        }
    }
}
