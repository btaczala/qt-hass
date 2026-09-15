pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// An entity's attributes as name/value rows, like the attributes section of
// Lovelace's more-info dialog: ones shown elsewhere or only meaningful to code
// are left out, names read like HA's ("color_temp" as "Color temp"). Scrolls
// when there are more than fit.
ListView {
    id: root

    property var attributes: ({})

    readonly property var hiddenAttributes: ["friendly_name", "icon", "entity_picture", "supported_features", "supported_color_modes", "unit_of_measurement", "device_class", "state_class", "attribution", "restored", "editable"]

    function label(key: string): string {
        const text = key.replace(/_/g, " ");
        return text.charAt(0).toUpperCase() + text.slice(1);
    }

    function format(value: var): string {
        if (value === null || value === undefined)
            return "—";
        if (Array.isArray(value))
            return value.map(item => typeof item === "object" ? JSON.stringify(item) : String(item)).join(", ");
        if (typeof value === "object")
            return JSON.stringify(value);
        // Timestamps, e.g. sun.sun's next_dawn, in local time.
        if (typeof value === "string" && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/.test(value)) {
            const date = new Date(value);
            if (!isNaN(date))
                return date.toLocaleString(Qt.locale(), Locale.ShortFormat);
        }
        return String(value);
    }

    implicitHeight: contentHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    spacing: 6
    model: Object.keys(root.attributes).filter(key => !root.hiddenAttributes.includes(key)).sort()

    ScrollBar.vertical: ScrollBar {}

    delegate: RowLayout {
        id: row

        required property string modelData

        width: ListView.view.width
        spacing: 12

        Label {
            Layout.preferredWidth: 1
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            text: root.label(row.modelData)
            font.pixelSize: 14
            color: root.Material.secondaryTextColor
            wrapMode: Text.Wrap
        }
        Label {
            Layout.preferredWidth: 1
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            text: root.format(root.attributes[row.modelData])
            font.pixelSize: 14
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.Wrap
        }
    }
}
