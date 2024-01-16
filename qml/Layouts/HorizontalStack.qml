import QtQuick
import QtQuick.Layouts

BaseLayout {
    id: root
    width: 480
    height: 480

    property bool scale: true

    property var children: [{
            "type": "Entity",
            "entity_id": " light.attic"
        }]
    Flickable {
        id: flickable
        anchors.fill: parent
        RowLayout {
            id: layout
            anchors.fill: parent
        }
    }

}
