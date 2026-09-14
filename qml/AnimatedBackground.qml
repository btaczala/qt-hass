pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Material

import QtHomeAssistant

// A smooth color-changing background, the Qt Quick take on the CSS animated
// gradient: a diagonal gradient several screens long slides slowly back and
// forth, so the window drifts through its colors.
//
// A plain gradient spreads neighboring colors only a few 8-bit shades apart
// over a whole screen, so each shade renders as a flat band tens of pixels
// wide -- visible diagonal stripes. When the build has Qt Shader Tools, the
// gradient is drawn by shaders/background.frag, which dithers before the
// shades get quantized and so removes the stripes. Otherwise (or under the
// software renderer, which can't run shaders) a rotated Rectangle gradient is
// used, with a faint noise tile on top that hides most of them.
//
// It keeps the scene redrawing every frame while the app is visible.
Item {
    id: root

    // Colors along the gradient, in order; the first four are used. Follows
    // the app's Material theme (System already resolved to Light or Dark).
    property list<color> darkColors: ["#10263f", "#1f5f73", "#4b2a6b", "#7c3a55"]
    property list<color> lightColors: ["#d6e6f5", "#cdeae8", "#e2d9f1", "#f3dce5"]
    property list<color> colors: root.Material.theme === Material.Dark ? root.darkColors : root.lightColors

    // Time to slide from one end of the gradient to the other.
    property int duration: 20000
    // Opacity of the fallback's dithering noise; 0 turns it off.
    property real dither: 0.03

    // The gradient spans this many window diagonals; one is visible at a time.
    readonly property int span: 4

    // Not "inactive": on desktop that would freeze it whenever focus moves
    // to another window. Hidden or suspended means nobody can see it.
    readonly property bool paused: Application.state === Qt.ApplicationHidden || Application.state === Qt.ApplicationSuspended

    readonly property bool useShader: Controler.backgroundShaderSupported && root.GraphicsInfo.api !== GraphicsInfo.Software

    Loader {
        anchors.fill: parent
        sourceComponent: root.useShader ? shaderGradient : fallbackGradient
    }

    Component {
        id: shaderGradient

        ShaderEffect {
            id: effect

            // Crossfades the gradient when the theme changes.
            property color color0: root.colors[0]
            property color color1: root.colors[1]
            property color color2: root.colors[2]
            property color color3: root.colors[3]
            property vector2d resolution: Qt.vector2d(effect.width, effect.height)
            property real span: root.span
            // How far along the gradient the window is, 0..1, driven by the
            // animation below. Normalized, so a resize or rotation needs no
            // restart.
            property real drift

            Behavior on color0 { ColorAnimation { duration: 400 } }
            Behavior on color1 { ColorAnimation { duration: 400 } }
            Behavior on color2 { ColorAnimation { duration: 400 } }
            Behavior on color3 { ColorAnimation { duration: 400 } }

            fragmentShader: "qrc:/res/QtHomeAssistant/shaders/background.frag.qsb"

            SequentialAnimation on drift {
                loops: Animation.Infinite
                paused: root.paused

                NumberAnimation {
                    from: 0
                    to: 1
                    duration: root.duration
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    from: 1
                    to: 0
                    duration: root.duration
                    easing.type: Easing.InOutSine
                }
            }
        }
    }

    Component {
        id: fallbackGradient

        // Only a transform moves -- the gradient is built once and Animators
        // run on the render thread.
        Item {
            id: fallback

            readonly property real diagonal: Math.hypot(fallback.width, fallback.height)
            readonly property real travel: (root.span - 1) * fallback.diagonal

            // Crossfades the gradient when the theme changes.
            component FadingStop: GradientStop {
                Behavior on color {
                    ColorAnimation {
                        duration: 400
                    }
                }
            }

            // A diagonal-sized square centered on the window covers it at any
            // rotation, so the band inside it can slide along its length
            // without exposing edges.
            Item {
                anchors.centerIn: parent
                width: fallback.diagonal
                height: fallback.diagonal
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

            // The noise lands after the gradient is already quantized, so it
            // can only hide the band edges, not remove them like the shader.
            Image {
                anchors.fill: parent
                visible: root.dither > 0
                opacity: root.dither
                source: "qrc:/res/QtHomeAssistant/images/noise.png"
                fillMode: Image.Tile
                smooth: false
            }

            SequentialAnimation {
                id: drift
                running: true
                loops: Animation.Infinite
                paused: root.paused

                YAnimator {
                    target: band
                    from: 0
                    to: -fallback.travel
                    duration: root.duration
                    easing.type: Easing.InOutSine
                }
                YAnimator {
                    target: band
                    from: -fallback.travel
                    to: 0
                    duration: root.duration
                    easing.type: Easing.InOutSine
                }
            }

            // Animators capture from/to when they start, so a resize or screen
            // rotation restarts the drift with the new distance.
            onTravelChanged: drift.restart()
        }
    }
}
