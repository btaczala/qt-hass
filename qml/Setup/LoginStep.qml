pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// Setup step 2: a Home Assistant login form, built from the login flow step's
// `data_schema` -- username and password first, then whatever HA asks next
// (e.g. a two-factor code).
ColumnLayout {
    id: root

    // The login flow's current `form` step: {step_id, data_schema, errors}.
    property var form: null
    property bool busy
    property string error
    property string server

    readonly property var schema: root.form?.data_schema ?? []

    signal submit(var values)
    signal back

    function labelOf(name: string): string {
        switch (name) {
        case "username":
            return qsTr("Username");
        case "password":
            return qsTr("Password");
        case "code":
            return qsTr("Code");
        case "multi_factor_auth_module":
            return qsTr("Two-factor authentication");
        default:
            return name;
        }
    }

    function values(): var {
        const result = {};
        for (let i = 0; i < fields.count; ++i) {
            const field = fields.itemAt(i) as SchemaField;
            if (field)
                result[field.name] = field.value;
        }
        return result;
    }

    // Filled in by every field, e.g. a password left empty.
    function complete(): bool {
        for (let i = 0; i < fields.count; ++i) {
            const field = fields.itemAt(i) as SchemaField;
            if (field && field.required && field.value === "")
                return false;
        }
        return true;
    }

    function trySubmit() {
        if (!root.busy && root.complete())
            root.submit(root.values());
    }

    // The first field takes focus whenever a new step arrives.
    onFormChanged: Qt.callLater(() => {
        const first = fields.itemAt(0) as SchemaField;
        if (first)
            first.focusInput();
    })

    // One entry of data_schema: {name, type: "string" | "select" | "boolean",
    // required, options ([[value, label]] for select)}.
    component SchemaField: ColumnLayout {
        id: field

        required property var modelData
        readonly property string name: field.modelData.name
        readonly property bool required: field.modelData.required ?? false
        readonly property string type: field.modelData.type
        readonly property var value: field.type === "boolean" ? check.checked : field.type === "select" ? (combo.currentValue ?? "") : text.text

        function focusInput() {
            if (field.type === "string")
                text.forceActiveFocus();
        }

        spacing: 4

        TextField {
            id: text
            Layout.fillWidth: true
            visible: field.type === "string"
            enabled: !root.busy
            placeholderText: root.labelOf(field.name)
            echoMode: field.name.includes("password") ? TextInput.Password : TextInput.Normal
            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText | (field.name === "code" ? Qt.ImhDigitsOnly : field.name.includes("password") ? Qt.ImhSensitiveData : Qt.ImhNone)
            onAccepted: root.trySubmit()
        }
        Label {
            visible: field.type === "select"
            text: root.labelOf(field.name)
            color: root.Material.hintTextColor
        }
        ComboBox {
            id: combo
            Layout.fillWidth: true
            visible: field.type === "select"
            enabled: !root.busy
            textRole: "text"
            valueRole: "value"
            model: (field.modelData.options ?? []).map(o => ({
                        value: o[0],
                        text: o[1]
                    }))
        }
        CheckBox {
            id: check
            visible: field.type === "boolean"
            enabled: !root.busy
            text: root.labelOf(field.name)
        }
    }

    spacing: 12

    Label {
        Layout.fillWidth: true
        text: root.form?.step_id === "mfa" ? qsTr("Enter the code from your two-factor authentication app.") : qsTr("Log in to %1 with your Home Assistant account.").arg(root.server)
        wrapMode: Text.WordWrap
    }

    Repeater {
        id: fields
        model: root.schema

        delegate: SchemaField {
            Layout.fillWidth: true
        }
    }

    ErrorLabel {
        Layout.fillWidth: true
        text: root.error
    }

    RowLayout {
        Layout.fillWidth: true

        Button {
            enabled: !root.busy
            flat: true
            text: qsTr("Back")
            onClicked: root.back()
        }
        Item {
            Layout.fillWidth: true
        }
        BusyIndicator {
            Layout.preferredHeight: loginButton.height
            visible: root.busy
        }
        Button {
            id: loginButton
            enabled: !root.busy
            highlighted: true
            text: qsTr("Log in")
            onClicked: root.trySubmit()
        }
    }
}
