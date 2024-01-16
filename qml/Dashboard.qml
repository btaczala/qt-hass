import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

Item {
    id: root
    width: 480
    height: 480

    // property var rootObject
    property int tabBarHeight: 50
    property var configuration

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

        TabBar {
            id: tabBar
            Layout.fillWidth: true
            Layout.minimumHeight: root.tabBarHeight
            Layout.maximumHeight: root.tabBarHeight
            Material.background: Material.Blue

            z: 99
        }
        StackLayout {
            id: stackView
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex
        }
    }
}
