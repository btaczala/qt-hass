import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

import QtHomeAssistant

// App settings, a full-screen page Main.qml opens over the dashboard. It's a
// popup so it covers the whole window, like the screensaver: on Android the
// window's content area stops short of the screen edges. Connection, dashboard
// and idle timeout live on Controler (C++ reads them; persisted with
// QSettings), the purely visual ones in the UiSettings object Main.qml owns,
// since only QML reads those. Both end up in the same QSettings store.
Popup {
    id: root

    required property UiSettings settings
    // Shown next to the dashboard's Reload button.
    property string dashboardStatus

    // Read by the About section; refreshed by reset().
    property var systemInfo: ({})

    // The dashboard source and Home Assistant dashboard being edited, applied
    // by Save and reload.
    property string dashboardSource
    property string dashboardConfig
    // The listed dashboards, plus the chosen one when the list lacks it (e.g.
    // it couldn't be read), so the choice still shows.
    readonly property var dashboardConfigs: root.dashboardConfig === "" || hassDashboards.names.includes(root.dashboardConfig) ? hassDashboards.names : [root.dashboardConfig].concat(hassDashboards.names)
    // The chosen dashboard's files, from its index.json entry; the saved ones
    // while the list lacks it.
    readonly property var dashboardEntry: hassDashboards.entry(root.dashboardConfig)
    readonly property bool savedConfig: root.dashboardConfig === Controler.dashboardConfig
    readonly property string dashboardMain: root.dashboardEntry?.main ?? (root.savedConfig ? Controler.dashboardMain : "main.qml")
    readonly property string dashboardScreensaver: root.dashboardEntry?.screensaver ?? (root.savedConfig ? Controler.dashboardScreensaver : "")

    // Asks the app to load the dashboard again, from Controler.dashboardUrl.
    signal reloadDashboardRequested

    // Refills the connection, dashboard and MQTT fields from Controler,
    // discarding unsaved edits, and refreshes the About section.
    function reset() {
        root.systemInfo = Controler.systemInfo();
        urlField.text = Controler.hassUrl;
        tokenField.text = Controler.hassToken;
        root.dashboardSource = Controler.dashboardSource;
        root.dashboardConfig = Controler.dashboardConfig;
        dashboardUrlField.text = Controler.customDashboardUrl;
        screensaverField.text = Controler.customScreensaver;
        if (root.dashboardSource === "hass")
            hassDashboards.refresh();
        mqttHostField.text = Controler.mqttBrokerHost;
        mqttPortField.text = Controler.mqttBrokerPort;
        mqttUsernameField.text = Controler.mqttUsername;
        mqttPasswordField.text = Controler.mqttPassword;
    }

    HassDashboardList {
        id: hassDashboards
    }

    parent: Overlay.overlay
    x: 0
    y: 0
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    // No z of its own: the screensaver has the same z and, opened later, draws
    // over it, and dashboard overlays are above both. A negative z would put
    // the popup under its own modal input blocker, so nothing in it could be
    // tapped.
    padding: 0

    modal: true
    dim: false
    focus: true
    // Escape, and Android's back button.
    closePolicy: Popup.CloseOnEscape

    onAboutToShow: {
        root.reset();
        scrollView.ScrollBar.vertical.position = 0;
    }

    enter: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: 150
        }
    }
    exit: Transition {
        NumberAnimation {
            property: "opacity"
            from: 1
            to: 0
            duration: 150
        }
    }

    background: Rectangle {
        color: root.Material.background
    }

    component SectionLabel: Label {
        Layout.topMargin: 16
        font.bold: true
        color: Material.accentColor
    }

    // A name/value row of the About section.
    component InfoLabel: Label {
        Layout.alignment: Qt.AlignTop
        color: Material.hintTextColor
    }
    component InfoValue: Label {
        Layout.fillWidth: true
        wrapMode: Text.WrapAnywhere
    }

    contentItem: Page {
        padding: 16
        background: null

        header: Item {
            implicitHeight: 64

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 16
                spacing: 8

                ToolButton {
                    Accessible.name: qsTr("Back")
                    contentItem: MdiIcon {
                        icon: "mdi:arrow-left"
                    }
                    onClicked: root.close()
                }
                Label {
                    Layout.fillWidth: true
                    text: qsTr("Settings")
                    font.pixelSize: 22
                }
            }
        }

        ScrollView {
            id: scrollView
            anchors.fill: parent
            contentWidth: availableWidth

            // Centered, and no wider than reads well on a large screen.
            ColumnLayout {
                x: (scrollView.availableWidth - width) / 2
                width: Math.min(scrollView.availableWidth, 720)
                spacing: 8

                SectionLabel {
                    Layout.topMargin: 0
                    text: qsTr("Connection")
                }

                TextField {
                    id: urlField
                    Layout.fillWidth: true
                    placeholderText: qsTr("URL, e.g. wss://host/api/websocket")
                    inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                }

                TextField {
                    id: tokenField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Long-lived access token")
                    echoMode: TextInput.Password
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                }

                Button {
                    Layout.fillWidth: true
                    text: qsTr("Log in again and set up this device...")
                    flat: true
                    onClicked: Controler.setupCompleted = false
                }

                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        Layout.fillWidth: true
                        text: HassAPI.connected ? qsTr("Connected") : qsTr("Not connected")
                        color: root.Material.hintTextColor
                    }

                    Button {
                        text: qsTr("Use built-in")
                        flat: true
                        onClicked: {
                            Controler.clearSavedConnection();
                            root.reset();
                            HassAPI.reconnect();
                        }
                    }

                    Button {
                        text: qsTr("Save and reconnect")
                        enabled: urlField.text.trim() !== ""
                        highlighted: true
                        onClicked: {
                            Controler.hassUrl = urlField.text.trim();
                            Controler.hassToken = tokenField.text.trim();
                            HassAPI.reconnect();
                        }
                    }
                }

                SectionLabel {
                    text: qsTr("Dashboard")
                }

                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        Layout.fillWidth: true
                        text: qsTr("Source")
                    }

                    ComboBox {
                        Layout.preferredWidth: 280
                        textRole: "text"
                        valueRole: "value"
                        model: [
                            { text: qsTr("Home Assistant www folder"), value: "hass" },
                            { text: qsTr("URL"), value: "url" }
                        ]
                        currentIndex: indexOfValue(root.dashboardSource)
                        onActivated: {
                            root.dashboardSource = currentValue;
                            if (root.dashboardSource === "hass")
                                hassDashboards.refresh();
                        }
                    }
                }

                // A dashboard from /config/www/qthass/<name>/, as index.json lists it.
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.dashboardSource === "hass"

                    Label {
                        Layout.fillWidth: true
                        text: qsTr("Dashboard")
                    }

                    ComboBox {
                        Layout.preferredWidth: 280
                        model: root.dashboardConfigs
                        displayText: currentIndex < 0 ? qsTr("Choose...") : currentText
                        currentIndex: root.dashboardConfigs.indexOf(root.dashboardConfig)
                        onActivated: index => root.dashboardConfig = root.dashboardConfigs[index]
                    }

                    ToolButton {
                        enabled: !hassDashboards.loading
                        contentItem: MdiIcon {
                            icon: "mdi:refresh"
                        }
                        Accessible.name: qsTr("Refresh the list")
                        onClicked: hassDashboards.refresh()
                    }
                }

                Label {
                    Layout.fillWidth: true
                    visible: root.dashboardSource === "hass"
                    text: {
                        if (hassDashboards.loading)
                            return qsTr("Reading /config/www/qthass/index.json...");
                        if (hassDashboards.error !== "")
                            return hassDashboards.error;
                        if (root.dashboardConfig === "")
                            return qsTr("Folders of /config/www/qthass/, as listed in its index.json.");
                        const url = Controler.hassDashboardsUrl + root.dashboardConfig + "/" + root.dashboardMain;
                        return root.dashboardScreensaver !== "" ? qsTr("%1\nScreensaver: %2").arg(url).arg(root.dashboardScreensaver) : url;
                    }
                    wrapMode: Text.WrapAnywhere
                    font.pixelSize: 12
                    color: hassDashboards.error !== "" ? root.Material.color(Material.Red, Material.Shade300) : root.Material.hintTextColor
                }

                TextField {
                    id: dashboardUrlField
                    Layout.fillWidth: true
                    visible: root.dashboardSource === "url"
                    placeholderText: qsTr("URL, e.g. http://homeassistant.local:8123/local/qthass/main.qml")
                    inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                }

                // Empty for the built-in screensaver.
                TextField {
                    id: screensaverField
                    Layout.fillWidth: true
                    visible: root.dashboardSource === "url"
                    placeholderText: qsTr("Screensaver file next to it (optional), e.g. MyScreensaver.qml")
                    inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                }

                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        Layout.fillWidth: true
                        text: root.dashboardStatus
                        wrapMode: Text.WordWrap
                        color: root.Material.hintTextColor
                    }

                    // Saves an edited source first. Either way the dashboard is
                    // loaded again from scratch, and the settings close to show it.
                    Button {
                        readonly property bool hass: root.dashboardSource === "hass"
                        readonly property bool edited: root.dashboardSource !== Controler.dashboardSource || (hass ? root.dashboardConfig !== Controler.dashboardConfig || root.dashboardMain !== Controler.dashboardMain || root.dashboardScreensaver !== Controler.dashboardScreensaver : dashboardUrlField.text.trim() !== Controler.customDashboardUrl || screensaverField.text.trim() !== Controler.customScreensaver)

                        text: edited ? qsTr("Save and reload") : qsTr("Reload")
                        enabled: hass ? root.dashboardConfig !== "" : dashboardUrlField.text.trim() !== "" || edited
                        highlighted: true
                        onClicked: {
                            Controler.dashboardSource = root.dashboardSource;
                            if (hass) {
                                // Read before dashboardConfig changes savedConfig.
                                const main = root.dashboardMain;
                                const screensaver = root.dashboardScreensaver;
                                Controler.dashboardConfig = root.dashboardConfig;
                                Controler.dashboardMain = main;
                                Controler.dashboardScreensaver = screensaver;
                            } else {
                                Controler.customDashboardUrl = dashboardUrlField.text.trim();
                                Controler.customScreensaver = screensaverField.text.trim();
                            }
                            dashboardUrlField.text = Controler.customDashboardUrl;
                            screensaverField.text = Controler.customScreensaver;
                            root.reloadDashboardRequested();
                            root.close();
                        }
                    }
                }

                SectionLabel {
                    text: qsTr("MQTT")
                }

                Label {
                    Layout.fillWidth: true
                    visible: !Controler.mqttSupported
                    text: qsTr("This build has no MQTT support.")
                    wrapMode: Text.WordWrap
                    color: root.Material.hintTextColor
                }

                // Publishes screensaver state for Home Assistant's fully_kiosk
                // integration; an empty host turns it off.
                ColumnLayout {
                    Layout.fillWidth: true
                    enabled: Controler.mqttSupported
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true

                        TextField {
                            id: mqttHostField
                            Layout.fillWidth: true
                            placeholderText: qsTr("Broker host (empty to disable)")
                            inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                        }

                        TextField {
                            id: mqttPortField
                            Layout.preferredWidth: 80
                            placeholderText: qsTr("Port")
                            inputMethodHints: Qt.ImhDigitsOnly
                            validator: IntValidator {
                                bottom: 1
                                top: 65535
                            }
                        }
                    }

                    TextField {
                        id: mqttUsernameField
                        Layout.fillWidth: true
                        placeholderText: qsTr("Username (optional)")
                        inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                    }

                    TextField {
                        id: mqttPasswordField
                        Layout.fillWidth: true
                        placeholderText: qsTr("Password (optional)")
                        echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Label {
                            Layout.fillWidth: true
                            text: Controler.mqttBrokerHost === "" ? qsTr("Disabled") : Controler.mqttConnected ? qsTr("Connected") : qsTr("Not connected")
                            color: root.Material.hintTextColor
                        }

                        Button {
                            text: qsTr("Use built-in")
                            flat: true
                            onClicked: {
                                Controler.clearSavedMqttConfig();
                                root.reset();
                            }
                        }

                        Button {
                            text: qsTr("Save and reconnect")
                            highlighted: true
                            onClicked: Controler.setMqttConfig(mqttHostField.text.trim(), parseInt(mqttPortField.text) || 1883, mqttUsernameField.text.trim(), mqttPasswordField.text)
                        }
                    }
                }

                SectionLabel {
                    text: qsTr("Appearance")
                }

                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        Layout.fillWidth: true
                        text: qsTr("Theme")
                    }

                    ComboBox {
                        id: themeBox
                        textRole: "text"
                        valueRole: "value"
                        model: [
                            { text: qsTr("Dark"), value: Material.Dark },
                            { text: qsTr("Light"), value: Material.Light },
                            { text: qsTr("System"), value: Material.System }
                        ]
                        Component.onCompleted: currentIndex = indexOfValue(root.settings.theme)
                        onActivated: root.settings.theme = currentValue
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        Layout.fillWidth: true
                        text: qsTr("Navigation bar")
                    }

                    ComboBox {
                        textRole: "text"
                        valueRole: "value"
                        model: [
                            { text: qsTr("Automatic"), value: "auto" },
                            { text: qsTr("Left"), value: "left" },
                            { text: qsTr("Right"), value: "right" },
                            { text: qsTr("Top"), value: "top" },
                            { text: qsTr("Bottom"), value: "bottom" }
                        ]
                        Component.onCompleted: currentIndex = indexOfValue(root.settings.navPosition)
                        onActivated: root.settings.navPosition = currentValue
                    }
                }

                Switch {
                    Layout.fillWidth: true
                    text: qsTr("Animated background")
                    checked: root.settings.animatedBackground
                    onToggled: root.settings.animatedBackground = checked
                }

                SectionLabel {
                    text: qsTr("System tray")
                }

                Switch {
                    Layout.fillWidth: true
                    text: qsTr("Show notifications")
                    checked: root.settings.showNotifications
                    onToggled: root.settings.showNotifications = checked
                }

                // Needs an admin user.
                Switch {
                    Layout.fillWidth: true
                    text: qsTr("Show repairs and updates")
                    checked: root.settings.showSettingsAlerts
                    onToggled: root.settings.showSettingsAlerts = checked
                }

                // Android only: nothing reads the battery elsewhere.
                Switch {
                    Layout.fillWidth: true
                    text: Controler.batterySupported ? qsTr("Show battery") : qsTr("Show battery (Android only)")
                    enabled: Controler.batterySupported
                    checked: root.settings.showBattery
                    onToggled: root.settings.showBattery = checked
                }

                SectionLabel {
                    text: qsTr("Idle")
                }

                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        Layout.fillWidth: true
                        text: qsTr("Idle timeout (seconds)")
                    }

                    SpinBox {
                        // 0 turns the screensaver off.
                        from: 0
                        to: 3600
                        stepSize: 10
                        editable: true
                        value: Controler.idleTimeoutSeconds
                        textFromValue: (value, locale) => value === 0 ? qsTr("Never") : Number(value).toLocaleString(locale, "f", 0)
                        valueFromText: (text, locale) => text === qsTr("Never") ? 0 : Number.fromLocaleString(locale, text)
                        onValueModified: Controler.idleTimeoutSeconds = value
                    }
                }

                // Android only: there's no portable equivalent elsewhere.
                Switch {
                    Layout.fillWidth: true
                    text: Controler.keepScreenOnSupported ? qsTr("Keep screen awake") : qsTr("Keep screen awake (Android only)")
                    enabled: Controler.keepScreenOnSupported
                    checked: Controler.keepScreenOn
                    onToggled: Controler.keepScreenOn = checked
                }

                SectionLabel {
                    text: qsTr("About")
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 16
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 6

                    InfoLabel {
                        text: qsTr("Name")
                    }
                    InfoValue {
                        text: root.systemInfo.name ?? ""
                    }

                    InfoLabel {
                        text: qsTr("IP address")
                    }
                    InfoValue {
                        text: (root.systemInfo.ipAddresses ?? []).join("\n") || qsTr("None")
                    }

                    InfoLabel {
                        text: qsTr("MAC address")
                    }
                    InfoValue {
                        text: root.systemInfo.mac ?? ""
                    }

                    InfoLabel {
                        text: qsTr("Remote admin")
                    }
                    InfoValue {
                        text: root.systemInfo.remoteAdminEnabled ? qsTr("Port %1").arg(root.systemInfo.remoteAdminPort) : qsTr("Disabled")
                    }

                    InfoLabel {
                        text: qsTr("App version")
                    }
                    InfoValue {
                        text: root.systemInfo.appVersion ?? ""
                    }

                    InfoLabel {
                        text: qsTr("System")
                    }
                    InfoValue {
                        text: root.systemInfo.system ?? ""
                    }

                    InfoLabel {
                        text: qsTr("Qt version")
                    }
                    InfoValue {
                        text: root.systemInfo.qtVersion ?? ""
                    }
                }
            }
        }
    }
}
