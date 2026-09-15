import QtQuick
import QtQuick.Layouts

import QtHomeAssistant

// A dashboard of the home's areas: three columns, the first two still empty,
// the third a scrolling list of area cards, as on Home Assistant's
// dashboard-home. Each card shows only the entities listed here. Tapping the
// Salon card opens its page, SalonPage.qml (listed in qmldir).
Dashboard {
    pages: [
        DashboardPage {
            title: qsTr("Areas")
            icon: "mdi:floor-plan"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16
                uniformCellSizes: true

                // Empty for now.
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }

                // Empty for now.
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }

                Flickable {
                    id: areas

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    // Below the system tray in the top right corner.
                    Layout.topMargin: 32
                    contentHeight: areaList.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    // As in Home Assistant's dashboard-home, first view: full-width
                    // cards, and pairs of half-width ones side by side. Controls are
                    // icons, as on its minimalistic area cards: lights toggle, the
                    // rest open their details.
                    ColumnLayout {
                        id: areaList

                        width: areas.width
                        spacing: 12

                        AreaCard {
                            Layout.fillWidth: true
                            areaId: "entrance"
                            name: qsTr("Przód")
                            hideUnavailable: true
                            sensors: ["sensor.pirateweather_temperature", "sensor.pirateweather_apparent_temperature"]
                            controls: [
                                {
                                    entityId: "lock.drzwi_wejsciowe",
                                    iconOnly: true
                                },
                                {
                                    entityId: "light.h60a6",
                                    iconOnly: true,
                                    tapAction: "toggle"
                                },
                                {
                                    entityId: "light.twinkly_004a99",
                                    iconOnly: true,
                                    tapAction: "toggle"
                                }
                            ]
                        }

                        AreaCard {
                            Layout.fillWidth: true
                            areaId: "backyard"
                            name: qsTr("Ogród")
                            hideUnavailable: true
                            sensors: [
                                "sensor.gw1200a_temperature_1",
                                "sensor.gw1200a_humidity_1",
                                {
                                    entityId: "binary_sensor.irrigation_unlimited_c1_m",
                                    stateStyles: {
                                        on: {
                                            color: "teal"
                                        },
                                        off: {
                                            icon: "mdi:water-off"
                                        }
                                    }
                                },
                                {
                                    entityId: "lawn_mower.garden_luba_lagmqaqf",
                                    icon: "mdi:robot-off",
                                    stateStyles: {
                                        mowing: {
                                            color: "green",
                                            icon: "mdi:robot-mower"
                                        }
                                    }
                                }
                            ]
                            controls: [
                                {
                                    entityId: "light.patio",
                                    icon: "mdi:light-flood-down",
                                    iconOnly: true,
                                    tapAction: "toggle"
                                },
                                {
                                    entityId: "cover.rolety_salon",
                                    iconOnly: true
                                }
                            ]
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            uniformCellSizes: true

                            AreaCard {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                areaId: "laundry_room"
                                name: qsTr("Pralnia")
                                hideUnavailable: true
                                sensors: [
                                    {
                                        entityId: "binary_sensor.presence_sensor_pralnia_zajetosc",
                                        stateStyles: {
                                            on: {
                                                color: "red"
                                            }
                                        }
                                    },
                                    {
                                        entityId: "binary_sensor.czy_pralko_suszarka_dziala",
                                        stateStyles: {
                                            on: {
                                                color: "lime",
                                                icon: "mdi:washing-machine"
                                            },
                                            off: {
                                                color: "black",
                                                icon: "mdi:washing-machine"
                                            }
                                        }
                                    },
                                    "sensor.presence_sensor_pralnia_temperatura"
                                ]
                                controls: [
                                    {
                                        entityId: "light.wlacznik_pralnia",
                                        iconOnly: true,
                                        tapAction: "toggle"
                                    },
                                    {
                                        entityId: "climate.shellywalldisplay_0008225ede24",
                                        iconOnly: true
                                    }
                                ]
                            }

                            AreaCard {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                areaId: "bathroom_downstairs"
                                name: qsTr("Łazienka")
                                hideUnavailable: true
                                sensors: [
                                    // Listed twice in Home Assistant, plain and styled; once here.
                                    {
                                        entityId: "binary_sensor.presence_multi_sensor_fp300_zajetosc",
                                        stateStyles: {
                                            on: {
                                                color: "red",
                                                icon: "mdi:motion-sensor"
                                            },
                                            off: {
                                                color: "white",
                                                icon: "mdi:motion-sensor-off"
                                            }
                                        }
                                    },
                                    "sensor.shellyplusht_d4d4da3a1e70_temperature"
                                ]
                                controls: [
                                    {
                                        entityId: "light.tx_ultimate_light_output_1",
                                        iconOnly: true,
                                        tapAction: "toggle"
                                    },
                                    {
                                        entityId: "climate.lazienka",
                                        iconOnly: true
                                    }
                                ]
                            }
                        }

                        AreaCard {
                            Layout.fillWidth: true
                            areaId: "garage"
                            name: qsTr("Garaż")
                            hideUnavailable: true
                            sensors: [
                                "sensor.sbht_003c_4b10_temperature",
                                "sensor.sbht_003c_4b10_humidity",
                                {
                                    entityId: "binary_sensor.czy_samochod_jest_w_garazu",
                                    stateStyles: {
                                        on: {
                                            color: "green",
                                            icon: "mdi:car"
                                        },
                                        off: {
                                            color: "red",
                                            icon: "mdi:car"
                                        }
                                    }
                                }
                            ]
                            controls: [
                                {
                                    entityId: "light.garaz_swiatla",
                                    iconOnly: true,
                                    tapAction: "toggle"
                                },
                                {
                                    entityId: "cover.garage_doors",
                                    icon: "mdi:garage",
                                    iconOnly: true,
                                    tapAction: "none"
                                }
                            ]
                        }

                        AreaCard {
                            Layout.fillWidth: true
                            areaId: "living_room"
                            name: qsTr("Salon")
                            hideUnavailable: true
                            tapAction: ({
                                    action: "navigate",
                                    page: "SalonPage.qml"
                                })
                            sensors: [
                                {
                                    entityId: "climate.klima_salon_klima_salon",
                                    attribute: "current_temperature",
                                    suffix: "°C",
                                    showIcon: false
                                }
                            ]
                            controls: [
                                {
                                    entityId: "light.ikea_salon_2",
                                    iconOnly: true,
                                    tapAction: "toggle"
                                },
                                {
                                    entityId: "light.ikea_biurko_2",
                                    icon: "mdi:desk",
                                    iconOnly: true,
                                    tapAction: "toggle"
                                },
                                {
                                    entityId: "media_player.pokoj_dzienny",
                                    iconOnly: true
                                },
                                {
                                    entityId: "light.szafka_rtv",
                                    icon: "mdi:television-ambient-light",
                                    iconOnly: true,
                                    tapAction: "toggle"
                                }
                            ]
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            uniformCellSizes: true

                            AreaCard {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                areaId: "albert"
                                name: qsTr("Albert")
                                hideUnavailable: true
                                sensors: [
                                    "sensor.shelly_blu_h_t_display_zb_95bd_temperatura",
                                    "binary_sensor.iotorero_sensor_611c_drzwi",
                                    {
                                        entityId: "binary_sensor.myggbett_door_window_sensor_drzwi",
                                        stateStyles: {
                                            on: {
                                                color: "red",
                                                icon: "mdi:window-open-variant"
                                            },
                                            off: {
                                                icon: "mdi:window-closed-variant"
                                            }
                                        }
                                    }
                                ]
                                controls: [
                                    {
                                        entityId: "light.wled_bisiek",
                                        iconOnly: true,
                                        tapAction: "toggle"
                                    },
                                    {
                                        entityId: "climate.klima_albert_6cc16d_klima_albert",
                                        iconOnly: true
                                    },
                                    {
                                        entityId: "climate.shellywalldisplay_0008225ede24",
                                        iconOnly: true
                                    }
                                ]
                            }

                            AreaCard {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                areaId: "office"
                                name: qsTr("Biuro")
                                hideUnavailable: true
                                sensors: ["sensor.ikea_vindstyrka_czujnik_temperatury_temperature"]
                                controls: [
                                    {
                                        entityId: "light.nspanel_office_relay_1",
                                        iconOnly: true,
                                        tapAction: "toggle"
                                    },
                                    {
                                        entityId: "climate.klima_office_6c521d_klima_biuro",
                                        iconOnly: true
                                    },
                                    {
                                        entityId: "climate.termostat_biuro_thermostat",
                                        iconOnly: true
                                    }
                                ]
                            }
                        }

                        AreaCard {
                            Layout.fillWidth: true
                            areaId: "bedroom"
                            name: qsTr("Sypialnia")
                            hideUnavailable: true
                            sensors: [
                                {
                                    entityId: "sensor.timmerflotte_temp_hmd_sensor_temperatura",
                                    suffix: "°C"
                                },
                                "binary_sensor.iotorero_sensor_5e0c_drzwi",
                                "binary_sensor.myggbett_door_window_sensor_drzwi_2"
                            ]
                            controls: [
                                {
                                    entityId: "cover.sypialnia",
                                    iconOnly: true
                                },
                                {
                                    entityId: "light.wlacznik_garderoba",
                                    icon: "mdi:wardrobe",
                                    iconOnly: true,
                                    tapAction: "toggle"
                                }
                            ]
                        }
                    }
                }
            }
        },
        // Navigated to by the Salon card, see its tapAction.
        DashboardPage {
            title: qsTr("Salon")
            icon: "mdi:sofa"
            source: "SalonPage.qml"
        }
    ]
}
