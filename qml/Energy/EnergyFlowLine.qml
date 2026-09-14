import QtQuick
import QtQuick.Shapes

// One connector of an EnergyFlowCard: a curve from `from` to `to` bent towards
// `control` (a control point on the straight line between them keeps it
// straight), and a dot that travels along it while power flows. The dot moves
// faster the larger this flow is relative to the card's biggest one, like
// power-flow-card-plus.
Item {
    id: root

    property point from
    property point to
    property point control: Qt.point((from.x + to.x) / 2, (from.y + to.y) / 2)

    // Watts (or, in the card's energy mode, Wh) flowing from `from` to `to`;
    // negative flows the other way.
    property real power: 0
    // Largest flow currently on the card, which travels fastest.
    property real maxPower: 1
    // Flows below this many W (or Wh) count as idle: grey line, no dot.
    property real threshold: 10

    property color color
    property color idleColor

    // Seconds for one dot to cross the line at the slowest and fastest.
    property real slowestDuration: 6
    property real fastestDuration: 0.75

    readonly property bool active: Math.abs(root.power) >= root.threshold
    readonly property real duration: root.slowestDuration - Math.min(1, Math.abs(root.power) / Math.max(1, root.maxPower)) * (root.slowestDuration - root.fastestDuration)

    // How far along the line the dot is, in the direction of flow.
    property real phase: 0

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeWidth: 1.5
            strokeColor: root.active ? root.color : root.idleColor
            startX: root.from.x
            startY: root.from.y

            PathQuad {
                x: root.to.x
                y: root.to.y
                controlX: root.control.x
                controlY: root.control.y
            }
        }
    }

    // The same curve again, as a plain Path: PathInterpolator can't follow the
    // ShapePath above -- Qt skips building the point cache it needs for shape
    // paths, so the interpolated position just sits at the end point.
    Path {
        id: motionPath
        startX: root.from.x
        startY: root.from.y

        PathQuad {
            x: root.to.x
            y: root.to.y
            controlX: root.control.x
            controlY: root.control.y
        }
    }

    PathInterpolator {
        id: travel
        path: motionPath
        progress: root.power >= 0 ? root.phase : 1 - root.phase
    }

    // Advances by elapsed frame time rather than running a looping
    // NumberAnimation, so a change in power changes the dot's speed smoothly
    // instead of only after the current loop restarts. Stops while the page is
    // hidden.
    FrameAnimation {
        running: root.active && root.visible
        onTriggered: root.phase = (root.phase + frameTime / root.duration) % 1
    }

    Rectangle {
        visible: root.active
        width: 8
        height: 8
        radius: 4
        x: travel.x - radius
        y: travel.y - radius
        color: root.color
    }
}
