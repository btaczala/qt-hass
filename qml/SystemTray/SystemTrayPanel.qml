pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

import QtHomeAssistant

// The expanded SystemTray: what's behind its counts, like Home Assistant's
// notification drawer and the repairs and updates lists under Settings.
// Opens exactly over the pill (`origin`, in overlay coordinates, set by
// SystemTray) and grows down and to the left out of it, keeping its top right
// corner: the counts fade out, the battery stays where it was, and the details
// fade in below. Closing shrinks it back into the pill.
Popup {
    id: root

    property HassAlerts alerts: null
    property bool showBattery: false
    property bool showNotifications: false
    property bool showSettingsAlerts: false
    property real fontSize: 14
    property color textColor: Material.foreground
    property color alertColor: Material.color(Material.Red)
    // The pill's background, blended into the panel's as it grows.
    property color pillColor: "transparent"
    // Where the pill is.
    property rect origin: Qt.rect(0, 0, 0, 0)
    // Kept at least this far inside the window when expanded.
    property real margin: 8
    // 0 as the pill, 1 fully expanded; animated by enter and exit.
    property real progress: 0

    readonly property var notifications: root.showNotifications && root.alerts ? root.alerts.notificationList : []
    readonly property var repairs: root.showSettingsAlerts && root.alerts ? root.alerts.repairList : []
    readonly property var updates: root.showSettingsAlerts && root.alerts ? root.alerts.updateList : []
    readonly property bool hasContent: root.notifications.length + root.repairs.length + root.updates.length > 0

    // The details are laid out at the final size throughout, and revealed by
    // the growing panel rather than reflowed on every frame.
    readonly property real expandedWidth: Math.max(root.origin.width, Math.min(420, root.origin.x + root.origin.width - root.margin))
    readonly property real expandedHeight: Math.max(root.origin.height, Math.min(root.origin.height + details.implicitHeight, parent ? parent.height - root.origin.y - root.margin : 0))

    // For the "ago" texts; refreshed on opening.
    property real now: Date.now()

    function mix(from: real, to: real, amount: real): real {
        return from + (to - from) * amount;
    }

    function mixColor(from: color, to: color, amount: real): color {
        return Qt.rgba(root.mix(from.r, to.r, amount), root.mix(from.g, to.g, amount), root.mix(from.b, to.b, amount), root.mix(from.a, to.a, amount));
    }

    // `progress` rescaled so that `from`..`to` maps to 0..1.
    function phase(from: real, to: real): real {
        return Math.max(0, Math.min(1, (root.progress - from) / (to - from)));
    }

    function ago(ms: real): string {
        const minutes = Math.floor((root.now - ms) / 60000);
        if (isNaN(minutes))
            return "";
        if (minutes < 1)
            return qsTr("just now");
        if (minutes < 60)
            return qsTr("%1 min ago").arg(minutes);
        if (minutes < 24 * 60)
            return qsTr("%1 h ago").arg(Math.floor(minutes / 60));
        return new Date(ms).toLocaleString(Qt.locale(), "d MMM HH:mm");
    }

    // Notification and repair texts link to the web or, relative, to pages on
    // the Home Assistant server.
    function openLink(link: string) {
        if (link.startsWith("/"))
            link = Controler.hassUrl.replace(/^ws/, "http").replace(/\/api\/websocket\/?$/, "") + link;
        Qt.openUrlExternally(link);
    }

    parent: Overlay.overlay
    // Grows from the pill's top right corner.
    width: root.mix(root.origin.width, root.expandedWidth, root.progress)
    height: root.mix(root.origin.height, root.expandedHeight, root.progress)
    x: root.origin.x + root.origin.width - width
    y: root.origin.y
    padding: 0
    modal: true
    dim: false
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    // Plain rather than Material's elevated one, so it's solid everywhere,
    // including under the software renderer.
    background: Rectangle {
        color: root.mixColor(root.pillColor, root.Material.dialogColor, root.phase(0, 0.5))
        radius: root.mix(root.origin.height / 2, 12, root.progress)
        border.color: Qt.alpha(root.Material.dividerColor, root.Material.dividerColor.a * root.progress)
    }

    enter: Transition {
        NumberAnimation {
            property: "progress"
            from: 0
            to: 1
            duration: 300
            easing.type: Easing.OutCubic
        }
    }
    exit: Transition {
        NumberAnimation {
            property: "progress"
            from: 1
            to: 0
            duration: 240
            easing.type: Easing.InOutCubic
        }
    }

    onAboutToShow: root.now = Date.now()
    // E.g. the last notification dismissed elsewhere.
    onHasContentChanged: if (!root.hasContent)
        root.close()

    // Popups draw above the screensaver, so don't stay open under it.
    Connections {
        target: Controler
        function onScreensaverActiveChanged() {
            if (Controler.screensaverActive)
                root.close();
        }
    }

    component SectionHeader: RowLayout {
        id: header

        property string icon
        property string text

        Layout.fillWidth: true
        Layout.topMargin: 8
        spacing: 8

        MdiIcon {
            icon: header.icon
            iconSize: 20
            color: header.Material.accent
        }

        Label {
            Layout.fillWidth: true
            text: header.text
            font.pixelSize: 14
            font.weight: Font.Medium
            color: header.Material.accent
        }
    }

    // One notification, repair or update.
    component Entry: ColumnLayout {
        id: entry

        property string title
        property string body
        property string meta
        property color metaColor: entry.Material.hintTextColor
        property string link

        Layout.fillWidth: true
        spacing: 2

        Label {
            Layout.fillWidth: true
            text: entry.title
            wrapMode: Text.Wrap
            font.weight: Font.Medium
        }

        Label {
            Layout.fillWidth: true
            visible: entry.body !== ""
            text: entry.body
            textFormat: Text.MarkdownText
            wrapMode: Text.Wrap
            color: entry.Material.secondaryTextColor
            onLinkActivated: link => root.openLink(link)
        }

        RowLayout {
            Layout.fillWidth: true
            visible: entry.meta !== "" || entry.link !== ""

            Label {
                Layout.fillWidth: true
                text: entry.meta
                font.pixelSize: 12
                color: entry.metaColor
            }

            Label {
                visible: entry.link !== ""
                text: "<a href=\"%1\">%2</a>".arg(entry.link).arg(qsTr("Learn more"))
                textFormat: Text.StyledText
                font.pixelSize: 12
                linkColor: entry.Material.accent
                onLinkActivated: link => root.openLink(link)
            }
        }

        MenuSeparator {
            Layout.fillWidth: true
            padding: 0
        }
    }

    contentItem: Item {
        clip: true

        // The pill's row, in the same place, so the battery doesn't move.
        SystemTrayIndicators {
            anchors.right: parent.right
            anchors.rightMargin: root.fontSize * 0.6
            y: (root.origin.height - height) / 2
            showBattery: root.showBattery
            alerts: root.alerts
            showNotifications: root.showNotifications
            showSettingsAlerts: root.showSettingsAlerts
            fontSize: root.fontSize
            textColor: root.textColor
            alertColor: root.alertColor
            countsOpacity: 1 - root.phase(0, 0.4)
        }

        // Tapping the pill's spot again collapses it.
        MouseArea {
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.origin.height
            onClicked: root.close()
        }

        ScrollView {
            id: scroll

            anchors.right: parent.right
            y: root.origin.height
            width: root.expandedWidth
            height: root.expandedHeight - root.origin.height
            opacity: root.phase(0.4, 1)
            contentWidth: availableWidth

            ColumnLayout {
                id: details
                width: scroll.availableWidth
                spacing: 6

                Item {
                    implicitHeight: 4
                }

                SectionHeader {
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    visible: root.notifications.length > 0
                    icon: "mdi:bell"
                    text: qsTr("Notifications (%1)").arg(root.notifications.length)
                }

                Repeater {
                    model: root.notifications

                    Entry {
                        required property var modelData
                        Layout.rightMargin: 16
                        Layout.leftMargin: 44
                        title: modelData.title !== "" ? modelData.title : qsTr("Notification")
                        body: modelData.message
                        meta: root.ago(modelData.created)
                    }
                }

                SectionHeader {
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    visible: root.repairs.length > 0
                    icon: "mdi:wrench"
                    text: qsTr("Repairs (%1)").arg(root.repairs.length)
                }

                Repeater {
                    model: root.repairs

                    Entry {
                        required property var modelData
                        Layout.rightMargin: 16
                        Layout.leftMargin: 44
                        title: modelData.title
                        body: modelData.description
                        meta: [modelData.domain, modelData.severity, root.ago(modelData.created)].filter(part => part).join(" · ")
                        metaColor: modelData.severity === "critical" || modelData.severity === "error" ? Material.color(Material.Red) : modelData.severity === "warning" ? Material.color(Material.Orange) : Material.hintTextColor
                        link: modelData.learnMoreUrl
                    }
                }

                SectionHeader {
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    visible: root.updates.length > 0
                    icon: "mdi:package-up"
                    text: qsTr("Updates (%1)").arg(root.updates.length)
                }

                Repeater {
                    model: root.updates

                    Entry {
                        required property var modelData
                        Layout.rightMargin: 16
                        Layout.leftMargin: 44
                        title: modelData.title ?? modelData.entityId
                        meta: qsTr("%1 → %2").arg(modelData.installed ?? "?").arg(modelData.latest ?? "?")
                    }
                }

                Item {
                    implicitHeight: 4
                }
            }
        }
    }
}
