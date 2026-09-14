import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

import QtHomeAssistant

// App settings, shown in Main.qml's drawer. Connection and idle timeout live on
// Controler (C++ reads them; persisted with QSettings), the purely visual ones
// in the UiSettings object Main.qml owns, since only QML reads those. Both end
// up in the same QSettings store.
Page {
    id: root

    required property UiSettings settings

    // Read by the About section; refreshed by reset().
    property var systemInfo: ({})

    // Refills the connection and MQTT fields from Controler, discarding
    // unsaved edits, and refreshes the About section.
    function reset() {
        root.systemInfo = Controler.systemInfo();
        urlField.text = Controler.hassUrl;
        tokenField.text = Controler.hassToken;
        mqttHostField.text = Controler.mqttBrokerHost;
        mqttPortField.text = Controler.mqttBrokerPort;
        mqttUsernameField.text = Controler.mqttUsername;
        mqttPasswordField.text = Controler.mqttPassword;
    }

    padding: 16
    background: null

    Component.onCompleted: root.reset()

    header: Label {
        text: qsTr("Settings")
        font.pixelSize: 22
        padding: 16
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

    ScrollView {
        id: scrollView
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: scrollView.availableWidth
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

            Switch {
                Layout.fillWidth: true
                text: qsTr("Animated background")
                checked: root.settings.animatedBackground
                onToggled: root.settings.animatedBackground = checked
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
