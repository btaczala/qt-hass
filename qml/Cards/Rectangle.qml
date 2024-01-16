import QtQuick

Rectangle {
    property var entity_data
    color: entity_data.color ? entity_data.color : "black"

    width: 100
    height: 50
}
