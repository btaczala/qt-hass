import QtQuick
import QtQuick.Layouts

import QtHomeAssistant

// A dashboard of area cards, one per room, each showing only the entities
// listed here. The three cards show the three header options: the area's
// picture, its icon, and a picture from a URL.
Dashboard {
    pages: [
        DashboardPage {
            title: qsTr("Areas")
            icon: "mdi:floor-plan"

            Flickable {
                id: flickable

                anchors.fill: parent
                contentHeight: grid.implicitHeight + 2 * grid.y
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                GridLayout {
                    id: grid

                    x: (flickable.width - width) / 2
                    y: 16
                    width: Math.min(flickable.width - 32, 1200)
                    columns: Math.max(1, Math.floor((grid.width + columnSpacing) / (380 + columnSpacing)))
                    columnSpacing: 16
                    rowSpacing: 16
                    uniformCellWidths: true

                    AreaCard {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        areaId: "living_room"
                        sensors: ["sensor.pod_oknem_temperature", "binary_sensor.pod_oknem_motion_sensor"]
                        controls: [
                            {
                                entityId: "light.salon",
                                name: qsTr("Główne światło"),
                                tapAction: "toggle"
                            },
                            {
                                entityId: "light.jadalnia_2",
                                // Its own icon is from a custom set the app can't draw.
                                icon: "mdi:ceiling-light",
                                tapAction: "toggle"
                            },
                            {
                                entityId: "light.wled",
                                name: qsTr("Szafka RTV"),
                                icon: "mdi:television-ambient-light",
                                iconOnly: true,
                                tapAction: "toggle"
                            },
                            {
                                entityId: "light.hue_play_gradient_lightstrip_1",
                                name: qsTr("Hue TV"),
                                icon: "mdi:led-strip-variant",
                                iconOnly: true,
                                tapAction: "toggle"
                            },
                            {
                                entityId: "climate.klima_salon_klima_salon",
                                name: qsTr("Klimatyzacja"),
                                icon: "mdi:air-conditioner"
                            }
                        ]
                    }

                    AreaCard {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        areaId: "kitchen"
                        displayType: "icon"
                        sensors: ["sensor.kitchen_temperature", "sensor.grillplats_plug_moc"]
                        controls: [
                            {
                                entityId: "light.kuchnia_ledy",
                                tapAction: "toggle"
                            },
                            // The fridge: details only, never toggled by a stray tap.
                            {
                                entityId: "switch.gniazdko_lodowka",
                                icon: "mdi:fridge"
                            }
                        ]
                    }

                    AreaCard {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        areaId: "laundry_room"
                        displayType: "url"
                        // Any picture: a path on the Home Assistant server, as here (the
                        // area's own picture, for the demo), or a full https:// URL.
                        pictureUrl: "/api/image/serve/4e96d873111b6cafdb6aca3cf760fd74/512x512"
                        sensors: ["sensor.presence_sensor_pralnia_temperatura", "sensor.presence_sensor_pralnia_wilgotnosc", "sensor.pralka_power"]
                        controls: [
                            {
                                entityId: "light.wlacznik_pralnia",
                                tapAction: "toggle"
                            }
                        ]
                    }
                }
            }
        }
    ]
}
