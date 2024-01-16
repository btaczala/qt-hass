import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var entity_data

    Layout.fillWidth: true


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
        return "qrc:/qt-hass/qml/Cards/ENTITY_TYPE.qml".replace("ENTITY_TYPE", file_name);
    }

    Flickable {
        id: flickable
        anchors.fill: parent
        RowLayout {
            id: layout
            anchors.fill: parent
        }
    }

    Component.onCompleted: {
        for (var entity of entity_data.cards) {
            var path = cardUrl(entity.type);
            const component = Qt.createComponent(path);
            var children_local = entity.children;
            if (component.status === Component.Ready) {
                const rootObject = component.createObject(layout, {
                        entity_data: entity
                    });
                // rootObject.width = layout.width / 4;
                rootObject.Layout.alignment = Qt.AlignVCenter;
            } else {
                console.log("Horizontal: Unable to create component from url", path, " error=", component.errorString());
            }
        }
    }
}
