import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    property var entity_data: QtObject {
        property string entity_id: "light.main"
    }

    color:"transparent"

    width: entity_data.width
    height: entity_data.height
}
