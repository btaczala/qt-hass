import QtQuick
import QtQuick.Controls
import QtQuick.Shapes

// Wind speed in a ring colored by strength, with a notch on the ring pointing
// where the wind blows to.
Item {
    id: root

    // In `unit` ("m/s", "km/h", "mph", "kn" or "ft/s").
    property real speed: 0
    property string unit: "m/s"
    // Degrees the wind comes from, 0 = north; NaN hides the notch.
    property real bearing: NaN
    property real size: 30

    readonly property real metersPerSecond: {
        switch (root.unit) {
        case "km/h":
            return root.speed / 3.6;
        case "mph":
            return root.speed * 0.44704;
        case "kn":
            return root.speed * 0.514444;
        case "ft/s":
            return root.speed * 0.3048;
        default:
            return root.speed;
        }
    }
    // Beaufort bands: calm to gentle breeze, moderate/fresh, strong, gale.
    readonly property color color: root.metersPerSecond < 5.5 ? "#66bb6a" : root.metersPerSecond < 10.8 ? "#ffa726" : root.metersPerSecond < 17.2 ? "#ef6c00" : "#e53935"

    implicitWidth: root.size
    implicitHeight: root.size

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: root.color
    }

    Label {
        anchors.centerIn: parent
        text: Math.round(root.speed)
        font.pixelSize: root.size * 0.42
        font.bold: true
        color: root.color
    }

    // Rotated about the center, so the notch at its top edge circles the ring.
    Item {
        anchors.fill: parent
        visible: !isNaN(root.bearing)
        rotation: root.bearing + 180

        Shape {
            x: (parent.width - 8) / 2
            y: -3
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: root.color
                startX: 0
                startY: 6
                PathLine {
                    x: 4
                    y: 0
                }
                PathLine {
                    x: 8
                    y: 6
                }
                PathLine {
                    x: 0
                    y: 6
                }
            }
        }
    }
}
