import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

import QtHomeAssistant

// The office panel's main view, after Home Assistant's nspanel-office /
// nspanel-main dashboard: a clock over two columns of cards, stacked into one
// when the window is narrow. Its "do not disturb" section is
// OfficeDoNotDisturb.qml, an overlay in main.qml.
Flickable {
    id: root

    readonly property real spacing: 8
    readonly property color green: "#4caf50"
    readonly property color blue: "#2196f3"
    readonly property color orange: "#ff9800"
    readonly property color red: "#f44336"

    contentHeight: content.implicitHeight + 2 * content.y
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: content

        x: (root.width - width) / 2
        y: 16
        width: Math.min(root.width - 32, 960)
        spacing: root.spacing

        Clock {
            Layout.alignment: Qt.AlignHCenter
            size: 240
            showDate: false
            weatherEntity: "weather.pirateweather"
            color: root.Material.foreground
        }

        GridLayout {
            Layout.fillWidth: true
            columns: content.width >= 640 ? 2 : 1
            columnSpacing: 16
            rowSpacing: root.spacing
            uniformCellWidths: true

            // Left column: routines, the vacuum, the front door and the alarm.
            ColumnLayout {
                Layout.fillWidth: true
                // Layouts fill by default; the shorter column would stretch its tiles.
                Layout.fillHeight: false
                Layout.alignment: Qt.AlignTop
                spacing: root.spacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.spacing
                    uniformCellSizes: true

                    ButtonCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 120
                        entityId: "script.dzien_dobry"
                    }
                    ButtonCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 120
                        entityId: "script.dobranoc"
                    }
                }

                Tile {
                    Layout.fillWidth: true
                    entityId: "vacuum.vaderek"
                    features: [
                        ButtonsFeature {
                            outlined: true
                            entries: [
                                {
                                    entityId: "button.vaderek_shortcut_1",
                                    icon: "mdi:vacuum",
                                    label: "Odk"
                                },
                                {
                                    entityId: "button.vaderek_shortcut_3",
                                    icon: "mdi:spray-bottle",
                                    label: "O + M"
                                }
                            ]
                        }
                    ]
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.spacing
                    uniformCellSizes: true

                    Tile {
                        id: frontDoor
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        entityId: "lock.drzwi_wejsciowe"
                        stateColor: frontDoor.isUnavailable ? frontDoor.Material.hintTextColor : frontDoor.entityState === "locked" ? root.green : root.red
                    }
                    AlarmCard {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        entityId: "alarm_control_panel.somfy_home_alarm_dom_bartek_taczala"
                        name: qsTr("Alarm")
                    }
                }
            }

            // Right column: the office itself.
            ColumnLayout {
                Layout.fillWidth: true
                // Layouts fill by default; the shorter column would stretch its tiles.
                Layout.fillHeight: false
                Layout.alignment: Qt.AlignTop
                spacing: root.spacing

                Tile {
                    id: occupancy
                    Layout.fillWidth: true
                    entityId: "binary_sensor.zajetosc_biura"
                    name: occupancy.isOn ? qsTr("Ojciec w biurze") : qsTr("Puste biuro")
                    icon: occupancy.isOn ? "mdi:motion-sensor" : "mdi:motion-sensor-off"
                    hideState: true
                    stateColor: occupancy.isOn ? root.red : root.green
                }

                Tile {
                    id: temperature
                    readonly property bool cold: Number(temperature.entityState) < 22 || !temperature.isActive

                    Layout.fillWidth: true
                    entityId: "sensor.ikea_vindstyrka_czujnik_temperatury_temperature"
                    name: qsTr("%1 °C").arg(temperature.entityState)
                    icon: "mdi:thermometer"
                    stateDisplay: temperature.cold ? qsTr("Zimno") : qsTr("ok")
                    stateColor: temperature.cold ? root.blue : root.green
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.spacing
                    uniformCellSizes: true

                    Tile {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        entityId: "script.szybkie_grzanie_w_biurze"
                        name: qsTr("grzanie")
                        features: [
                            ButtonsFeature {}
                        ]
                    }
                    Tile {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        entityId: "input_boolean.bartek_nie_przeszkadac"
                        features: [
                            ToggleFeature {}
                        ]
                    }
                }
            }
        }
    }
}
