import QtQuick
import QtQuick.Controls

QtObject {
    id: root
    property var dashboards: []
    Component.onCompleted: {
        var cards = [];
        cards.push({
                "type": "Spacer",
                "height": "50"
            });
        cards.push({
                "type": "Entity",
                "entity_id": "light.wlacznik_garaz"
            });
        cards.push({
                "type": "Rectangle",
                "color": "green"
            });
        // cards.push({
        //         "type": "Entity",
        //         "entity_id": " light.attic"
        //     });
        var config = {
            "name": "Home",
            "icon": "https://api.iconify.design/material-symbols/home-outline.svg",
            "type": "VerticalStack",
            "cards": cards
        };
        root.dashboards.push(config);
    }
}
