import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtMultimedia

import QtHomeAssistant
import "CameraUrls.js" as CameraUrls

// Full-screen live view for one camera entity, opened by tapping a
// CameraCard. Fetches an HLS URL from Home Assistant's "camera/stream"
// websocket command -- the same one its own frontend uses -- and plays it
// with QtMultimedia's Video type; like the camera_proxy snapshot URL
// CameraCard loads, the HLS URL already carries its own access token in the
// path, so no Authorization header is needed for either.
Popup {
    id: root

    required property string entity_id
    property string name

    property bool loading: false
    property string error: ""

    parent: Overlay.overlay
    x: 0
    y: 0
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    padding: 0
    modal: true
    closePolicy: Popup.CloseOnEscape
    background: Rectangle {
        color: "black"
    }

    function fetchStream() {
        root.error = "";
        root.loading = true;
        const sent = HassAPI.command("camera/stream", {
            entity_id: root.entity_id,
            format: "hls"
        }, root, (ok, json) => {
            root.loading = false;
            const result = ok ? JSON.parse(json) : null;
            if (!result?.url) {
                root.error = qsTr("Couldn't start the camera stream.");
                return;
            }
            video.source = CameraUrls.resolve(Controler.hassUrl, result.url);
        });
        if (!sent)
            root.error = qsTr("Not connected to Home Assistant.");
    }

    onOpened: root.fetchStream()
    onClosed: {
        video.stop();
        // Dropped, not just stopped: a stale token shouldn't linger for the
        // next open, which always fetches a fresh one anyway.
        video.source = "";
    }

    // Popups draw above the screensaver, so don't stay open under it.
    Connections {
        target: Controler
        function onScreensaverActiveChanged() {
            if (Controler.screensaverActive)
                root.close();
        }
    }

    contentItem: Item {
        Video {
            id: video
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectFit
            autoPlay: true
            onErrorOccurred: (error, errorString) => root.error = errorString
        }

        BusyIndicator {
            anchors.centerIn: parent
            running: root.loading
            visible: root.loading
        }

        Label {
            anchors.centerIn: parent
            visible: root.error !== ""
            text: root.error
            color: "white"
            wrapMode: Text.WordWrap
            width: Math.min(parent.width - 64, 400)
            horizontalAlignment: Text.AlignHCenter
        }

        RowLayout {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12
            spacing: 10

            Label {
                Layout.fillWidth: true
                text: root.name
                color: "white"
                font.pixelSize: 18
                elide: Text.ElideRight
            }
            ToolButton {
                contentItem: MdiIcon {
                    icon: "mdi:close"
                    color: "white"
                }
                onClicked: root.close()
            }
        }
    }
}
