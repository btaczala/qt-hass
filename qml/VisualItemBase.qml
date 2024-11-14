import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

Item {
    id: root
    property var entity_data
    property bool as_card: true
    width: loader.item ? loader.item.width : 0
    height: loader.item ? loader.item.height : 0
    Rectangle {
        color: Material.background
        anchors.fill: parent
        opacity: 0.4
        visible: root.as_card
        radius: 10
    }

    function cardUrl(card_type) {
        var split = card_type.split(":");
        var file_name;
        if (split[0] === "custom") {
            var custom = split[1].split("-");
            file_name = "Custom/";
            for (var name of custom) {
                file_name = file_name + name.charAt(0).toUpperCase() + name.slice(1);
            }
        } else {
            file_name = split[0].charAt(0).toUpperCase() + split[0].slice(1);
        }
        return "qrc:/QtHass/qml/Cards/ENTITY_TYPE.qml".replace("ENTITY_TYPE", file_name);
    }

    Loader {
        id: loader
    }

    Component.onCompleted: {
        var item_url = cardUrl(entity_data.type);
        loader.setSource(item_url, {
                entity_data: root.entity_data
            });
    }

    onWidthChanged: {
        loader.width = root.width;
    }
}
