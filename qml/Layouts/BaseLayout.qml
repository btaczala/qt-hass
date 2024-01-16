import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property alias layout: loader.sourceComponent
    property var cards
    property var entity_data

    Flickable {
        id: flickable
        anchors.fill: parent

        Loader {
            id: loader
            anchors.fill: parent
        }
    }

    Component.onCompleted: {
        var height = 0;
        if (root.cards) {
            for (var entity of root.cards) {
                console.log("BaseLayout: creatiing");
                // var path = cardUrl(entity.type);
                var path = "qrc:/qt-hass/qml/VisualItemBase.qml";
                const component = Qt.createComponent(path);
                if (component.status === Component.Ready) {
                    const rootObject = component.createObject(loader.item, {
                            entity_data: entity
                        });
                    if (entity.fill_container) {
                        rootObject.Layout.fillWidth = true;
                    } else {
                    }
                    if (entity.height) {
                        rootObject.height = entity.height;
                    }
                    if (entity.width) {
                        rootObject.width = entity.width;
                    }
                    height = height + rootObject.height + loader.item.spacing;
                } else {
                    console.log("BaseLayout: error while creating ", component.errorString());
                }
                flickable.contentHeight = height;
            }
        }
    }
}
