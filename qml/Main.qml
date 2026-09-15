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

    BusyIndicator {
        anchors.centerIn: parent
        visible: !HassAPI.connected && Controler.setupCompleted
    }

    // The user's dashboard, from Controler.dashboardUrl; only while connected,
    // so no entity components exist until auth succeeds.
    DashboardHost {
        id: dashboardHost
        anchors.fill: parent
        active: HassAPI.connected && Controler.setupCompleted
        // "auto": along the short side, so the pages keep the long one.
        navPosition: uiSettings.navPosition !== "auto" ? uiSettings.navPosition : window.width > window.height ? "left" : "top"
        onSettingsRequested: settingsPage.open()
    }

    // Like a status bar, which Android hides in full screen. The navigation bar
    // is centered along its edge, so this corner stays clear of it.
    HassAlerts {
        id: hassAlerts
        watchNotifications: Controler.setupCompleted && uiSettings.showNotifications
        watchSettingsAlerts: Controler.setupCompleted && uiSettings.showSettingsAlerts
    }

    SystemTray {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 8
        showBattery: Controler.batterySupported && uiSettings.showBattery
        alerts: hassAlerts
        showNotifications: uiSettings.showNotifications
        showSettingsAlerts: uiSettings.showSettingsAlerts
        expandable: true
    }

    // The dashboard's navigation bar has its own settings button; this one is
    // for while there's no dashboard, e.g. to fix a wrong URL.
    ToolButton {
        id: menuButton
        visible: !dashboardHost.dashboard
        contentItem: MdiIcon {
            icon: "mdi:menu"
        }
        onClicked: settingsPage.open()
    }

    // Outside the dashboard Loader on purpose: settings have to be reachable
    // before the first successful connection, e.g. to fix a wrong URL.
    SettingsPage {
        id: settingsPage
        settings: uiSettings
        dashboardStatus: screensaver.error !== "" ? qsTr("%1\nThe screensaver has errors, showing the built-in one: %2").arg(dashboardHost.statusText).arg(screensaver.error) : dashboardHost.statusText
        onReloadDashboardRequested: dashboardHost.reload()
    }

    // Entity details for the whole app, opened by Controler.requestDetails
    // (e.g. a Tile's more-info action). Outside the dashboard, so there's one.
    DetailsOverlay {}

    // First run, or set up again from the settings page.
    Loader {
        anchors.fill: parent
        active: !Controler.setupCompleted
        sourceComponent: SetupWizard {}
    }

    Screensaver {
        id: screensaver
        visible: Controler.screensaverActive
        // The dashboard's own, when it has one; kept while disconnected.
        source: DashboardSync.screensaverUrl
        showBattery: Controler.batterySupported && uiSettings.showBattery
        alerts: hassAlerts
        showNotifications: uiSettings.showNotifications
        showSettingsAlerts: uiSettings.showSettingsAlerts
        // Whatever the loaded dashboard asks for.
        weatherEntity: dashboardHost.dashboard?.screensaverWeatherEntity ?? ""
        energyEntities: dashboardHost.dashboard?.screensaverEnergyEntities ?? null
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
                settingsPage.close();
        }
    }
}
