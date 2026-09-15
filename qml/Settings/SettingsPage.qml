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

    // Asks the app to load the dashboard again, from Controler.dashboardUrl.
    signal reloadDashboardRequested

    // Refills the connection, dashboard and MQTT fields from Controler,
    // discarding unsaved edits, and refreshes the About section.
    function reset() {
        root.systemInfo = Controler.systemInfo();
        urlField.text = Controler.hassUrl;
        tokenField.text = Controler.hassToken;
        dashboardUrlField.text = Controler.dashboardUrl;
        mqttHostField.text = Controler.mqttBrokerHost;
        mqttPortField.text = Controler.mqttBrokerPort;
        mqttUsernameField.text = Controler.mqttUsername;
        mqttPasswordField.text = Controler.mqttPassword;
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

                TextField {
                    id: dashboardUrlField
                    Layout.fillWidth: true
                    placeholderText: qsTr("URL, e.g. http://homeassistant.local:8123/local/qthass/main.qml")
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

                    // Saves an edited URL first. Either way the dashboard is
                    // loaded again from scratch, and the settings close to show it.
                    Button {
                        readonly property bool edited: dashboardUrlField.text.trim() !== Controler.dashboardUrl

                        text: edited ? qsTr("Save and reload") : qsTr("Reload")
                        enabled: dashboardUrlField.text.trim() !== "" || edited
                        highlighted: true
                        onClicked: {
                            Controler.dashboardUrl = dashboardUrlField.text.trim();
                            dashboardUrlField.text = Controler.dashboardUrl;
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
