pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

import QtHomeAssistant

// Alarm details, like Home Assistant's more-info for alarm panels: the state,
// Disarm and Arm buttons, every arm mode the panel supports, and a keypad for
// panels that take a code. Wide enough, the keypad sits beside the rest.
Popup {
    id: root

    required property AlarmEntity alarm
    property string title

    readonly property bool hasCode: root.alarm.codeFormat !== null
    readonly property bool numericCode: root.alarm.codeFormat === "number"
    readonly property bool canArm: !root.alarm.busy && root.alarm.available && (!root.alarm.codeArmRequired || codeField.text !== "")

    function arm(mode: var) {
        root.alarm.arm(mode, codeField.text);
        codeField.clear();
    }

    function disarm() {
        root.alarm.disarm(codeField.text);
        codeField.clear();
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(parent ? parent.width - 32 : 0, root.hasCode ? 760 : 480)
    height: Math.min(parent ? parent.height - 32 : 0, implicitHeight)
    padding: 20
    topPadding: 8
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    Material.roundedScale: Material.MediumScale

    onClosed: {
        codeField.clear();
        root.alarm.error = "";
    }

    // Popups draw above the screensaver, so don't stay open under it.
    Connections {
        target: Controler
        function onScreensaverActiveChanged() {
            if (Controler.screensaverActive)
                root.close();
        }
    }

    // A button with an MDI icon: beside the text, or above it when `stacked`.
    component IconButton: Button {
        id: button

        property string iconName
        property bool stacked

        contentItem: GridLayout {
            columns: button.stacked ? 1 : 2
            columnSpacing: 8
            rowSpacing: 2

            MdiIcon {
                Layout.alignment: Qt.AlignCenter
                icon: button.iconName
                iconSize: button.stacked ? 26 : 20
                color: button.highlighted ? button.Material.primaryHighlightedTextColor : button.checked ? button.Material.accentColor : button.Material.foreground
                opacity: button.enabled ? 1 : 0.4
            }
            Label {
                Layout.alignment: Qt.AlignCenter
                text: button.text
                font: button.font
                color: button.highlighted ? button.Material.primaryHighlightedTextColor : button.checked ? button.Material.accentColor : button.Material.foreground
                opacity: button.enabled ? 1 : 0.4
            }
        }
    }

    contentItem: ColumnLayout {
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            MdiIcon {
                icon: root.alarm.icon
                iconSize: 26
                color: root.alarm.color
            }
            Label {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: 20
                elide: Text.ElideRight
            }
            ToolButton {
                contentItem: MdiIcon {
                    icon: "mdi:close"
                }
                onClicked: root.close()
            }
        }

        // Scrolls on screens too short for it all.
        Flickable {
            id: flickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitHeight: body.implicitHeight
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {}

            GridLayout {
                id: body
                width: flickable.width
                columns: root.hasCode && flickable.width >= 600 ? 2 : 1
                columnSpacing: 32
                rowSpacing: 20

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 16

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16

                        Rectangle {
                            Layout.preferredWidth: 72
                            Layout.preferredHeight: 72
                            radius: 36
                            color: Qt.rgba(root.alarm.color.r, root.alarm.color.g, root.alarm.color.b, 0.2)

                            Behavior on color {
                                ColorAnimation {
                                    duration: 200
                                }
                            }

                            MdiIcon {
                                anchors.centerIn: parent
                                icon: root.alarm.icon
                                iconSize: 40
                                color: root.alarm.color
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Label {
                                Layout.fillWidth: true
                                text: root.alarm.stateLabel
                                font.pixelSize: 24
                                elide: Text.ElideRight
                            }
                            Label {
                                Layout.fillWidth: true
                                visible: root.alarm.attributes.changed_by ? true : false
                                text: qsTr("By %1").arg(root.alarm.attributes.changed_by ?? "")
                                color: root.Material.secondaryTextColor
                                elide: Text.ElideRight
                            }
                        }
                        BusyIndicator {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            running: root.alarm.busy || root.alarm.pending
                            visible: running
                        }
                    }

                    ErrorLabel {
                        Layout.fillWidth: true
                        text: root.alarm.error
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        IconButton {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            iconName: "mdi:lock-open-variant"
                            text: qsTr("Disarm")
                            enabled: !root.alarm.busy && root.alarm.available && !root.alarm.disarmed
                            highlighted: enabled
                            Material.accent: root.alarm.disarmedColor
                            onClicked: root.disarm()
                        }
                        IconButton {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            iconName: "mdi:lock"
                            text: root.alarm.defaultMode ? qsTr("Arm %1").arg(root.alarm.defaultMode.label.toLowerCase()) : qsTr("Arm")
                            enabled: root.canArm && root.alarm.defaultMode !== null && root.alarm.disarmed
                            highlighted: enabled
                            Material.accent: root.alarm.armedColor
                            onClicked: root.arm(root.alarm.defaultMode)
                        }
                    }

                    Label {
                        visible: root.alarm.modes.length > 0
                        text: qsTr("Modes")
                        font.bold: true
                        color: root.Material.accentColor
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        visible: root.alarm.modes.length > 0
                        columns: Math.max(1, Math.min(root.alarm.modes.length, Math.floor(width / 100)))
                        columnSpacing: 8
                        rowSpacing: 8

                        Repeater {
                            model: root.alarm.modes

                            delegate: IconButton {
                                id: modeButton
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                Layout.preferredHeight: 80
                                stacked: true
                                flat: false
                                iconName: modelData.icon
                                text: modelData.label
                                checkable: false
                                checked: root.alarm.state === modelData.state
                                enabled: root.canArm && !checked
                                onClicked: root.arm(modeButton.modelData)
                            }
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        visible: root.alarm.codeArmRequired && codeField.text === "" && root.alarm.disarmed
                        text: qsTr("Enter the code to arm.")
                        wrapMode: Text.WordWrap
                        font.pixelSize: 12
                        color: root.Material.hintTextColor
                    }
                }

                // Code entry: a field, plus a keypad for numeric codes.
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    visible: root.hasCode
                    spacing: 8

                    TextField {
                        id: codeField
                        Layout.fillWidth: true
                        placeholderText: qsTr("Code")
                        echoMode: TextInput.Password
                        horizontalAlignment: TextInput.AlignHCenter
                        font.pixelSize: 20
                        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | (root.numericCode ? Qt.ImhDigitsOnly : Qt.ImhNone)
                        // The keypad is the input for numeric codes; no
                        // on-screen keyboard popping up over it.
                        readOnly: root.numericCode && Qt.platform.os === "android"
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        visible: root.numericCode
                        columns: 3
                        columnSpacing: 8
                        rowSpacing: 8

                        Repeater {
                            model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "clear", "0", "backspace"]

                            delegate: Button {
                                id: key
                                required property string modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 56
                                flat: key.modelData === "clear" || key.modelData === "backspace"
                                enabled: key.modelData === "clear" || key.modelData === "backspace" ? codeField.text !== "" : true
                                focusPolicy: Qt.NoFocus
                                text: key.modelData === "clear" ? qsTr("Clear") : key.modelData === "backspace" ? "" : key.modelData
                                font.pixelSize: key.flat ? 14 : 22
                                onClicked: {
                                    if (key.modelData === "clear")
                                        codeField.clear();
                                    else if (key.modelData === "backspace")
                                        codeField.text = codeField.text.slice(0, -1);
                                    else
                                        codeField.text += key.modelData;
                                }

                                MdiIcon {
                                    anchors.centerIn: parent
                                    visible: key.modelData === "backspace"
                                    icon: "mdi:backspace-outline"
                                    opacity: key.enabled ? 1 : 0.4
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
