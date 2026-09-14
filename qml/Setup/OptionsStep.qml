import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

import QtHomeAssistant

// Setup step 3: how this device behaves, prefilled with the current settings.
// Nothing is applied until finish(), see SetupWizard.
ColumnLayout {
    id: root

    property bool busy
    property string error

    // {deviceName, keepScreenOn, idleTimeoutSeconds, remoteAdminEnabled,
    // remoteAdminPassword, remoteAdminPort}
    signal finish(var options)

    function reset() {
        nameField.text = Controler.deviceName;
        keepAwake.checked = Controler.keepScreenOn;
        idleBox.value = Controler.idleTimeoutSeconds;
        remoteSwitch.checked = Controler.remoteAdminEnabled;
        passwordField.text = Controler.remoteAdminPassword;
        portField.text = Controler.remoteAdminPort;
    }

    Component.onCompleted: root.reset()

    spacing: 8

    Label {
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        text: qsTr("Logged in. A few more choices for this device — all of them can be changed later.")
        wrapMode: Text.WordWrap
    }

    TextField {
        id: nameField
        Layout.fillWidth: true
        placeholderText: qsTr("Device name, e.g. Kitchen tablet")
    }
    Label {
        Layout.fillWidth: true
        text: qsTr("Shown in Home Assistant, e.g. next to the access token this device uses.")
        wrapMode: Text.WordWrap
        font.pixelSize: 12
        color: root.Material.hintTextColor
    }

    Switch {
        id: keepAwake
        Layout.fillWidth: true
        Layout.topMargin: 8
        visible: Controler.keepScreenOnSupported
        text: qsTr("Keep screen awake")
    }

    RowLayout {
        Layout.fillWidth: true

        Label {
            Layout.fillWidth: true
            text: qsTr("Screensaver after (seconds)")
        }
        SpinBox {
            id: idleBox
            from: 0
            to: 3600
            stepSize: 10
            editable: true
            textFromValue: (value, locale) => value === 0 ? qsTr("Never") : Number(value).toLocaleString(locale, "f", 0)
            valueFromText: (text, locale) => text === qsTr("Never") ? 0 : Number.fromLocaleString(locale, text)
        }
    }

    Switch {
        id: remoteSwitch
        Layout.fillWidth: true
        Layout.topMargin: 8
        text: qsTr("Remote control")
    }
    Label {
        Layout.fillWidth: true
        text: qsTr("Lets Home Assistant's Fully Kiosk Browser integration control this device over the local network (screensaver, screenshots).")
        wrapMode: Text.WordWrap
        font.pixelSize: 12
        color: root.Material.hintTextColor
    }
    RowLayout {
        Layout.fillWidth: true
        visible: remoteSwitch.checked

        TextField {
            id: passwordField
            Layout.fillWidth: true
            placeholderText: qsTr("Password")
            echoMode: TextInput.Password
            inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
        }
        TextField {
            id: portField
            Layout.preferredWidth: 80
            placeholderText: qsTr("Port")
            inputMethodHints: Qt.ImhDigitsOnly
            validator: IntValidator {
                bottom: 1
                top: 65535
            }
        }
    }

    ErrorLabel {
        Layout.fillWidth: true
        text: root.error
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 8

        Item {
            Layout.fillWidth: true
        }
        BusyIndicator {
            Layout.preferredHeight: finishButton.height
            visible: root.busy
        }
        Button {
            id: finishButton
            enabled: !root.busy && nameField.text.trim() !== "" && (!remoteSwitch.checked || (passwordField.text !== "" && portField.acceptableInput))
            highlighted: true
            text: qsTr("Finish")
            onClicked: root.finish({
                deviceName: nameField.text.trim(),
                keepScreenOn: keepAwake.checked,
                idleTimeoutSeconds: idleBox.value,
                remoteAdminEnabled: remoteSwitch.checked,
                remoteAdminPassword: passwordField.text,
                remoteAdminPort: parseInt(portField.text) || 2323
            })
        }
    }
}
