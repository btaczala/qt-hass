import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import QtHomeAssistant

// One CameraCard per camera, tap to open its live view. Just
// camera.g3_flex_high_resolution_channel for now, to test end to end on a
// real device; add more CameraCard entries here once that's confirmed.
Flickable {
    id: root

    readonly property real spacing: 8

    contentHeight: content.implicitHeight + 2 * content.y
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}

    GridLayout {
        id: content

        x: (root.width - width) / 2
        y: 16
        width: Math.min(root.width - 32, 960)
        columns: content.width >= 640 ? 2 : 1
        columnSpacing: root.spacing
        rowSpacing: root.spacing

        CameraCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 220
            entityId: "camera.g3_flex_high_resolution_channel"
            streamUrl: "rtsps://192.168.1.1:7441/35uQS9Oe0JmexY3X?enableSrtp"
        }
        CameraCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 220
            entityId: "camera.g5_bullet_high"
            streamUrl: "rtsps://192.168.1.1:7441/Bse9MSF2o74QlETC?enableSrtp"
        }
        CameraCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 220
            entityId: "camera.g5_turret_ultra_high_resolution_channel"
            streamUrl: "rtsps://192.168.1.1:7441/KLVkA2PkVs06RHnI?enableSrtp"
        }
        CameraCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 220
            entityId: "camera.g5_turret_ultra_high_resolution_channel_2"
            streamUrl: "rtsps://192.168.1.1:7441/QHeiGmzjLrgiMT69?enableSrtp"
        }
    }
}
