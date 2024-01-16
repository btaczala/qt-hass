import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Hass.js" as Hass

Item {
    id: root
    property var entity_data

    readonly property string entity_type: {
        var str2 = entity_data.entity.split(".")[0];
        str2 = str2.charAt(0).toUpperCase() + str2.slice(1);
        return str2;
    }

    property var update

    Connections {
        target: controller

        function onHassApiRequestDataUpdated(entity_id: string, entity_data: var) {
            if (root.entity_data.entity === entity_data["entity_id"] && root.update) {
                root.update(entity_data);
            }
        }
    }

    Timer {
        running: true
        interval: 1000
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            Hass.request_update_state(entity_data.entity);
        }
    }
}
