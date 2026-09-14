import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// Setup step 1: where Home Assistant is.
ColumnLayout {
    id: root

    property alias url: urlField.text
    property bool busy
    property string error
    // Offered when there already is a working setup to go back to (e.g. a
    // bundled token).
    property bool canSkip

    signal next
    signal skip

    spacing: 12

    Label {
        Layout.fillWidth: true
        text: qsTr("Enter the address of your Home Assistant, the same one you open in a browser.")
        wrapMode: Text.WordWrap
    }

    TextField {
        id: urlField
        Layout.fillWidth: true
        enabled: !root.busy
        placeholderText: qsTr("e.g. http://homeassistant.local:8123")
        inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
        focus: true
        onAccepted: if (nextButton.enabled)
            root.next()
    }

    ErrorLabel {
        Layout.fillWidth: true
        text: root.error
    }

    RowLayout {
        Layout.fillWidth: true

        Button {
            visible: root.canSkip
            enabled: !root.busy
            flat: true
            text: qsTr("Skip, keep current connection")
            onClicked: root.skip()
        }
        Item {
            Layout.fillWidth: true
        }
        BusyIndicator {
            Layout.preferredHeight: nextButton.height
            visible: root.busy
        }
        Button {
            id: nextButton
            enabled: !root.busy && urlField.text.trim() !== ""
            highlighted: true
            text: qsTr("Next")
            onClicked: root.next()
        }
    }
}
