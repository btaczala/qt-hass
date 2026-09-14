pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtHomeAssistant

ApplicationWindow {
    id: window
    width: 1024
    height: 800
    visible: true
    title: qsTr("Qt Home Assistant")
    visibility: platform == "android" ? Window.FullScreen : Window.Windowed // qmllint disable unqualified

    Material.theme: uiSettings.theme

    UiSettings {
        id: uiSettings
    }

    background: Rectangle {
        color: window.Material.background

        Loader {
            anchors.fill: parent
            active: uiSettings.animatedBackground
            sourceComponent: AnimatedBackground {}
        }
    }

    // Outside the dashboard Loader on purpose: settings have to be reachable
    // before the first successful connection, e.g. to fix a wrong URL.
    Drawer {
        id: drawer
        width: Math.min(window.width * 0.85, 420)
        height: window.height

        onOpened: settingsPage.reset()

        contentItem: SettingsPage {
            id: settingsPage
            settings: uiSettings
        }
    }

    BusyIndicator {
        anchors.centerIn: parent
        visible: !HassAPI.connected
    }

    Loader {
        active: HassAPI.connected
        anchors.fill: parent
        sourceComponent: Dashboard {
            leadingInset: menuButton.width
        }
    }

    ToolButton {
        id: menuButton
        contentItem: MdiIcon {
            icon: "mdi:menu"
        }
        onClicked: drawer.open()
    }

    Screensaver {
        visible: Controler.screensaverActive
    }

    DoNotDisturb {
        entityId: "input_boolean.bartek_nie_przeszkadac"
    }

    Component.onCompleted: {
        HassAPI.connect();
    }

    Connections {
        target: HassAPI
        function onConnectedChanged() {
            Controler.hassConnected = HassAPI.connected;
        }
    }
}
