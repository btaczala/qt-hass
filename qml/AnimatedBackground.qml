import QtQuick
import QtQuick.Controls.Material

// A smooth color-changing background, the Qt Quick take on the CSS animated
// gradient: a diagonal gradient several screens long slides slowly back and
// forth, so the window drifts through its colors.
//
// Only a transform moves -- the gradient is built once and Animators run on the
// render thread -- so it stays cheap on low-end tablets. It does keep the scene
// redrawing every frame while the app is visible.
Item {
    id: root

    // Colors along the gradient, in order; the first four are used. Follows
    // the app's Material theme (System already resolved to Light or Dark).
    property list<color> darkColors: ["#10263f", "#1f5f73", "#4b2a6b", "#7c3a55"]
    property list<color> lightColors: ["#d6e6f5", "#cdeae8", "#e2d9f1", "#f3dce5"]
    property list<color> colors: root.Material.theme === Material.Dark ? root.darkColors : root.lightColors

    // Crossfades the gradient when the theme changes.
    component FadingStop: GradientStop {
        Behavior on color {
            ColorAnimation {
                duration: 400
            }
        }
    }
    // Time to slide from one end of the gradient to the other.
    property int duration: 20000

    // The gradient spans this many window diagonals; one is visible at a time.
    readonly property int span: 4
    readonly property real diagonal: Math.hypot(root.width, root.height)
    readonly property real travel: (root.span - 1) * root.diagonal

    // A diagonal-sized square centered on the window covers it at any rotation,
    // so the band inside it can slide along its length without exposing edges.
    Item {
        anchors.centerIn: parent
        width: root.diagonal
        height: root.diagonal
        rotation: -45

        Rectangle {
            id: band
            width: parent.width
            height: parent.height * root.span

            gradient: Gradient {
                FadingStop {
                    position: 0
                    color: root.colors[0]
                }
                FadingStop {
                    position: 1 / 3
                    color: root.colors[1]
                }
                FadingStop {
                    position: 2 / 3
                    color: root.colors[2]
                }
                FadingStop {
                    position: 1
                    color: root.colors[3]
                }
            }
        }
    }

    SequentialAnimation {
        id: drift
        running: true
        loops: Animation.Infinite
        // Not "inactive": on desktop that would freeze it whenever focus moves
        // to another window. Hidden or suspended means nobody can see it.
        paused: Application.state === Qt.ApplicationHidden || Application.state === Qt.ApplicationSuspended

        YAnimator {
            target: band
            from: 0
            to: -root.travel
            duration: root.duration
            easing.type: Easing.InOutSine
        }
        YAnimator {
            target: band
            from: -root.travel
            to: 0
            duration: root.duration
            easing.type: Easing.InOutSine
        }
    }

    // Animators capture from/to when they start, so a resize or screen
    // rotation restarts the drift with the new distance.
    onTravelChanged: drift.restart()
}
