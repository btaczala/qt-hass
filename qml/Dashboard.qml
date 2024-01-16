import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

Item {
    id: root
    width: 480
    height: 480

    property int tabBarHeight: 50
    property var configuration
    property int click: 0

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

    Component.onCompleted: {
        if (configuration.views) {
            for (var view of configuration.views) {
                addDashboard(view);
            }
        }
    }

    function addDashboard(yaml) {
        var item = tabButton.createObject(tabBar, {
                text: yaml.name,
                height: root.tabBarHeight,
                width: 48
            });
        tabBar.addItem(item);
        if (yaml.icon)
            item.icon.source = yaml.icon;
        var url = "qrc:/qt-hass/qml/Layouts/STACK_VIEW.qml".replace('STACK_VIEW', yaml.type);
        const component = Qt.createComponent(url);
        if (component.status === Component.Ready) {
            var rootObject = component.createObject(stackView, {
                    cards: yaml.cards,
                    entity_data: yaml
                });
        } else {
            console.log("dashboard: unable to create ", url, " error = ", component.errorString());
        }
    }

    ColumnLayout {
        anchors.fill: parent

        Item {
            Layout.fillWidth: true
            Layout.minimumHeight: root.tabBarHeight
            Layout.maximumHeight: root.tabBarHeight
            z: 99
            RowLayout {
                anchors.fill: parent
                spacing: 0
                Rectangle {
                    visible: AppSettings.showSettingDrawerIcon
                    Layout.fillHeight: true
                    Layout.preferredWidth: 80
                    color: Qt.rgba(128 / 255, 203 / 255, 196 / 255, 1)
                    Button {
                        id: control
                        anchors.fill: parent
                        flat: true
                        icon.source: "qrc:/qt-hass/images/drawer.svg"
                        onClicked: drawer.open()
                    }
                }
                TabBar {
                    id: tabBar
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Material.background: Material.Teal
                }
            }
        }
        StackLayout {
            id: stackView
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex
        }
    }
}
