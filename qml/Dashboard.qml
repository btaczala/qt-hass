import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtHass

Item {
    id: root
    width: 480
    height: 480

    property int tabBarHeight: 50
    property var configuration
    property int click: 0

    property var pages

    Timer {
        id: resetTimer
        interval: 5000
        repeat: true
        onTriggered: {
            root.click = 0;
        }
    }

    Component {
        id: tabButton
        TabButton {
            id: control
            contentItem: Item {
                IconImage {
                    anchors.centerIn: parent
                    source: control.icon.source
                    sourceSize.width: 24
                    sourceSize.height: 24
                    color: "white"
                }
            }

            onClicked: {
                resetTimer.start();
                root.click++;
                if (root.click > 6) {
                    AppSettings.showSettingDrawerIcon = !AppSettings.showSettingDrawerIcon;
                    root.click = 0;
                }
            }
        }
    }

    // Loader {
    //     source: controller.pathFor("default_dashboard/Dashboard.qml")
    //     anchors.fill: parent
    //
    //     anchors.margins: 10
    // }

    Light {
        width: 100
        height: 100
        entity: "light.office_main_bulbs"
    }

}
