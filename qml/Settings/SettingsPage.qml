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

    // Refills the connection fields from Controler, discarding unsaved edits.
    function reset() {
        urlField.text = Controler.hassUrl;
        tokenField.text = Controler.hassToken;
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
                    from: 10
                    to: 3600
                    stepSize: 10
                    editable: true
                    value: Controler.idleTimeout
                    onValueModified: Controler.idleTimeout = value
                }
            }
        }
    }
}
