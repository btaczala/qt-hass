import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Hass.js" as Hass

Popup {
    id: root

    property string entity_name
    property string friendly_name

    function url(type: string, name: string) {
        var str2 = type.replace(' ', '');
        str2 = str2.charAt(0).toUpperCase() + str2.slice(1);
        return "qrc:/qt-hass/qml/Details/CARD.qml".replace('CARD', str2);
    }

    function openDetails(entity_id: string, friendly_name: string) {
        const entity_type = entity_id.split(".")[0].replace(' ', '');
        root.friendly_name = friendly_name;
        loader.setSource(url(entity_type, entity_name), {
                "entity_data": {
                    entity: entity_id
                }
            });
        root.open();
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 20
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 60

            RowLayout {
                anchors.fill: parent
                spacing: 10
                IconImage {
                    id: closeButton
                    width: 48
                    height: 48
                    source: "https://api.iconify.design/material-symbols/close.svg"
                    color: Material.foreground

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.close();
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: friendly_name
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 24
                }
            }
        }

        Loader {
            id: loader
            Layout.fillHeight: true
            Layout.fillWidth: true
        }
    }
}
