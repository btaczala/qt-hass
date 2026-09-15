import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

import QtHomeAssistant

// What the main screen shows instead of a dashboard: why there's none (not
// defined, still loading, failed), any details, and buttons to reload or to
// open the settings, where the dashboard is set.
Item {
    id: root

    property string icon: "mdi:view-dashboard-edit-outline"
    property string title
    property string text
    // Error messages, shown in a scrollable box.
    property string details
    property bool busy: false
    property bool canReload: false

    signal settingsRequested
    signal reloadRequested

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(root.width - 32, 720)
        spacing: 12

        MdiIcon {
            Layout.alignment: Qt.AlignHCenter
            visible: !root.busy
            icon: root.icon
            iconSize: 72
            color: root.Material.hintTextColor
        }
        BusyIndicator {
            Layout.alignment: Qt.AlignHCenter
            visible: root.busy
            running: root.busy
        }
        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.title
            font.pixelSize: 24
        }
        Label {
            Layout.fillWidth: true
            visible: root.text !== ""
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.text
            color: root.Material.secondaryTextColor
        }

        Pane {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(detailsLabel.implicitHeight + topPadding + bottomPadding, root.height * 0.4)
            visible: root.details !== ""
            padding: 12
            Material.elevation: 0
            Material.roundedScale: Material.SmallScale
            Material.background: Qt.rgba(0, 0, 0, 0.3)

            ScrollView {
                anchors.fill: parent
                contentWidth: availableWidth
                clip: true

                Label {
                    id: detailsLabel
                    width: parent.width
                    text: root.details
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.PlainText
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8
            spacing: 8

            Button {
                visible: root.canReload
                text: qsTr("Reload")
                flat: true
                onClicked: root.reloadRequested()
            }
            Button {
                text: qsTr("Open settings")
                highlighted: true
                onClicked: root.settingsRequested()
            }
        }
    }
}
