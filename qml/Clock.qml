pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import QtHomeAssistant

// Time and date, by default in dim greys for dark full-screen overlays (Screensaver,
// DoNotDisturb). Ticks only while visible; minutePassed() fires on each new
// minute, e.g. to move the clock around. With showWeather and a weatherEntity,
// the current weather's icon sits next to the time; tapping it opens a
// WeatherCard.
Column {
    id: root

    // Scales the whole clock; the time is a fifth of this tall.
    property real size: 400
    property date now: new Date()
    property color color: "#b0b0b0"
    property color dateColor: "#808080"
    property bool showDate: true
    property bool showWeather: true
    property string weatherEntity

    signal minutePassed

    // Catches up straight away, e.g. when shown again after a while hidden.
    function refresh() {
        root.now = new Date();
    }

    spacing: root.size * 0.01

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: root.size * 0.04

        Label {
            id: time
            text: root.now.toLocaleTimeString(Qt.locale(), "HH:mm")
            font.pixelSize: root.size * 0.2
            font.weight: Font.Light
            color: root.color
        }

        Loader {
            anchors.verticalCenter: time.verticalCenter
            active: root.showWeather && root.weatherEntity !== ""
            visible: active

            sourceComponent: WeatherIcon {
                condition: weather.state
                size: root.size * 0.16

                HassEntity {
                    id: weather
                    entityId: root.weatherEntity
                }

                TapHandler {
                    onTapped: weatherPopup.open()
                }
            }
        }
    }
    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.showDate
        text: root.now.toLocaleDateString(Qt.locale(), "dddd, d MMMM")
        font.pixelSize: root.size * 0.05
        color: root.dateColor
    }

    Popup {
        id: weatherPopup

        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(parent ? parent.width - 32 : 0, 640)
        padding: 0
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: null

        // Only while open, so the forecast isn't fetched in the background.
        contentItem: Loader {
            active: weatherPopup.visible
            sourceComponent: WeatherCard {
                entityId: root.weatherEntity
            }
        }

        // Popups draw above the screensaver, so don't stay open under it.
        Connections {
            target: Controler
            function onScreensaverActiveChanged() {
                if (Controler.screensaverActive)
                    weatherPopup.close();
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible
        onTriggered: {
            const now = new Date();
            const minuteChanged = now.getMinutes() !== root.now.getMinutes();
            root.now = now;
            if (minuteChanged)
                root.minutePassed();
        }
    }

    onVisibleChanged: if (root.visible)
        root.refresh()
}
