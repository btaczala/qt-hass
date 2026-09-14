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
        visible: !HassAPI.connected && Controler.setupCompleted
    }

    Loader {
        id: dashboardLoader
        active: HassAPI.connected && Controler.setupCompleted
        anchors.fill: parent
        sourceComponent: Dashboard {
            // "auto": along the short side, so the pages keep the long one.
            navPosition: uiSettings.navPosition !== "auto" ? uiSettings.navPosition : window.width > window.height ? "left" : "top"
            onMenuRequested: drawer.open()
        }
    }

    // The dashboard's navigation bar has its own settings button; this one is
    // for while there's no dashboard, e.g. to fix a wrong URL.
    ToolButton {
        id: menuButton
        visible: dashboardLoader.status !== Loader.Ready
        contentItem: MdiIcon {
            icon: "mdi:menu"
        }
        onClicked: drawer.open()
    }

    // First run, or set up again from the settings page.
    Loader {
        anchors.fill: parent
        active: !Controler.setupCompleted
        sourceComponent: SetupWizard {}
    }

    Screensaver {
        visible: Controler.screensaverActive
    }

    DoNotDisturb {
        entityId: "input_boolean.bartek_nie_przeszkadac"
    }

    // Until set up, the wizard connects once it has a token.
    Component.onCompleted: if (Controler.setupCompleted)
        HassAPI.connect()

    Connections {
        target: HassAPI
        function onConnectedChanged() {
            Controler.hassConnected = HassAPI.connected;
        }
    }

    Connections {
        target: Controler
        function onSetupCompletedChanged() {
            if (!Controler.setupCompleted)
                drawer.close();
        }
    }
}
