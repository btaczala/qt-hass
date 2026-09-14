import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

import QtHomeAssistant
import "CameraUrls.js" as CameraUrls

// A Home Assistant camera as a thumbnail -- HA's own camera_proxy snapshot
// endpoint, reloaded on a timer -- that opens a full live view
// (CameraStreamPopup, HLS via QtMultimedia) on tap. Modeled on Lovelace's
// picture-entity card. Along the top, CameraDetails shows motion, darkness
// and the last motion, from the sensors CameraSensors finds for the camera
// (or the `*Entity` properties).
EntityBase {
    id: root

    property string name
    // How often the snapshot is reloaded. HA's camera_proxy grabs a fresh
    // frame from the camera on every request, so this is real, if not quite
    // live, movement -- the tap-to-open view is the actual live stream.
    property int refreshSeconds: 10
    // Optional; found on the camera's device when empty. See CameraSensors.
    property string motionEntity
    property string darkEntity
    property string lastMotionEntity

    readonly property var attributes: root.entity_data?.attributes ?? ({})
    readonly property string displayName: root.name || root.attributes.friendly_name || root.entity_id
    readonly property string proxyPath: root.attributes.entity_picture ?? ""

    update: function (response) {
        root.entity_data = JSON.parse(response);
    }

    function reload() {
        if (!root.proxyPath)
            return;
        const sep = root.proxyPath.includes("?") ? "&" : "?";
        image.source = CameraUrls.resolve(Controler.hassUrl, root.proxyPath) + sep + "_=" + Date.now();
    }

    width: 320
    height: 180
    padding: 0
    Material.elevation: 4
    Material.roundedScale: Material.SmallScale

    onProxyPathChanged: root.reload()

    CameraSensors {
        id: sensors
        cameraEntity: root.entity_id
        motionEntity: root.motionEntity
        darkEntity: root.darkEntity
        lastMotionEntity: root.lastMotionEntity
    }

    Image {
        id: image
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        // A fresh request every reload(), not the previous frame.
        cache: false
        asynchronous: true
    }

    Rectangle {
        anchors.fill: parent
        visible: image.status !== Image.Ready
        color: "black"

        MdiIcon {
            anchors.centerIn: parent
            icon: "mdi:cctv"
            iconSize: 48
            color: "#808080"
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 8
        radius: 4
        color: Qt.rgba(0, 0, 0, 0.55)
        width: label.implicitWidth + 12
        height: label.implicitHeight + 6
        visible: root.displayName !== ""

        Label {
            id: label
            anchors.centerIn: parent
            text: root.displayName
            color: "white"
            font.pixelSize: 12
        }
    }

    CameraDetails {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 8
        sensors: sensors
    }

    TapHandler {
        onTapped: stream.open()
    }

    Timer {
        interval: root.refreshSeconds * 1000
        repeat: true
        // Not while the live view is open -- no point refreshing a thumbnail
        // hidden behind its own popup.
        running: root.visible && !stream.visible
        onTriggered: root.reload()
    }

    CameraStreamPopup {
        id: stream
        entity_id: root.entity_id
        name: root.displayName
        sensors: sensors
    }
}
