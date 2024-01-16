import QtQuick
import QtQuick.Controls

QtObject {
    id: root
    property var dashboards: []
    Component.onCompleted: {
        var cards = [];
        cards.push({
                "type": "Rectangle",
                "height": "30",
                "color": "blue"
            });
        cards.push({
                "type": "Light",
                "entity_id": "light.office_main_bulbs",
                "fill_container": true
            });
        cards.push({
                "type": "Entity",
                "entity_id": "light.office_main_bulbs",
                "width": 90
            });
        cards.push({
                "type": "Entity",
                "entity_id": "light.wlacznik_garderoba"
            });
        cards.push({
                "type": "Entity",
                "entity_id": "light.wlacznik_swiatla_sypialnia"
            });
        cards.push({
                "type": "Horizontal",
                "cards": [{
                        "type": "Entity",
                        "entity_id": "light.shelly_rgbw_led_channel_1",
                        "name": "LED 1",
                        "width": 70
                    }, {
                        "type": "Entity",
                        "entity_id": "light.shelly_rgbw_led_channel_2"
                    }, {
                        "type": "Entity",
                        "entity_id": "light.shelly_rgbw_led_channel_3"
                    }, {
                        "type": "Entity",
                        "entity_id": "light.shelly_rgbw_led_channel_4"
                    }]
            });
        cards.push({
                "type": "Entity",
                "entity_id": "light.wlacznik_lazienka_bisia"
            });
        var config = {
            "name": "Home",
            "icon": "https://api.iconify.design/material-symbols/home-outline.svg",
            "type": "VerticalStack",
            "cards": cards
        };
        cards = [];
        cards.push({
                "type": "Entity",
                "entity_id": "light.wlacznik_lazienka_bisia"
            });
        cards.push({
                "type": "Entity",
                "entity_id": "light.wlacznik_lazienka_bisia"
            });
        cards.push({
                "type": "Entity",
                "entity_id": "light.wlacznik_lazienka_bisia"
            });
        root.dashboards.push(config);
        var config = {
            "name": "Home",
            "icon": "https://api.iconify.design/ph/airplay-duotone.svg",
            "type": "GridStack",
            "cards": cards,
            "columns": 3
        };
        root.dashboards.push(config);
    }
}
