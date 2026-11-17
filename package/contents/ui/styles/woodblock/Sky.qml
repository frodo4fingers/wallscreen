import QtQuick
import QtQuick.Shapes
import QtQuick.Particles

// Sky (ukiyo-e): flat gradient, ink-pressed top bokashi band, warm horizon bokashi strip,
// flat sun, flat moon with phase, sparse crisp stars. No Timers, no per-frame JS, no blur.
Item {
    id: root

    property color topColor: "#3d7cc9"
    property color bottomColor: "#f3e7c4"
    property color bandColor: "#1f4e9c"
    property color horizonColor: "#f3e7c4"
    property real horizonAlpha: 0.35
    property real sunX: 0.5
    property real sunY: 0.2
    property real moonX: 0.5
    property real moonY: 0.2
    property bool sunVisible: true
    property bool moonVisible: false
    property real moonPhase: 0.5      // 0 new, 0.5 full
    property real starOpacity: 0
    property bool running: true

    readonly property real unit: Math.min(width, height)
    readonly property real horizonY: 0.62
    readonly property color ink: "#1d1a2e"
    readonly property real lineW: Math.max(1.5, unit * 0.0018)

    clip: true

    // ---- slow crossfades (20 s) ----
    property color _top: topColor
    property color _bottom: bottomColor
    property color _band: bandColor
    property color _horizon: horizonColor
    property real _hAlpha: horizonAlpha
    Behavior on _top { ColorAnimation { duration: 20000 } }
    Behavior on _bottom { ColorAnimation { duration: 20000 } }
    Behavior on _band { ColorAnimation { duration: 20000 } }
    Behavior on _horizon { ColorAnimation { duration: 20000 } }
    Behavior on _hAlpha { NumberAnimation { duration: 20000 } }

    // base: flat vertical gradient
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: root._top }
            GradientStop { position: 1.0; color: root._bottom }
        }
    }

    // top bokashi band: solid for the first 35 %, then fades out
    Rectangle {
        width: root.width
        height: root.height * 0.22
        gradient: Gradient {
            GradientStop { position: 0.00; color: root._band }
            GradientStop { position: 0.35; color: root._band }
            GradientStop { position: 1.00; color: Qt.rgba(root._band.r, root._band.g, root._band.b, 0) }
        }
    }

    // horizon bokashi strip: 14 % tall, bottom edge at HORIZON_Y, fades up and down
    Rectangle {
        width: root.width
        height: root.height * 0.14
        y: root.height * (root.horizonY - 0.14)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(root._horizon.r, root._horizon.g, root._horizon.b, 0) }
            GradientStop { position: 0.5; color: Qt.rgba(root._horizon.r, root._horizon.g, root._horizon.b, root._hAlpha) }
            GradientStop { position: 1.0; color: Qt.rgba(root._horizon.r, root._horizon.g, root._horizon.b, 0) }
        }
    }

    // ---- stars: sparse, small crisp dots ----
    Item {
        id: stars
        anchors.fill: parent
        opacity: root.starOpacity
        visible: opacity > 0.01

        // ~90 stars at 1920x1080, clamped 60..110
        readonly property int count: Math.max(60, Math.min(110,
            Math.round(root.width * root.height * 0.6 * 7.2e-5)))
        readonly property int life: 9000

        ParticleSystem {
            id: sys
            running: stars.visible
            paused: !root.running
        }
        ItemParticle {
            system: sys
            // outer item carries the particle life fade, inner dot twinkles (2-5 s, random phase)
            delegate: Item {
                width: Math.max(2, root.unit * 0.004)
                height: width
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "#fdf6dc"
                    SequentialAnimation on opacity {
                        running: true
                        paused: running && !root.running
                        PauseAnimation { duration: Math.round(Math.random() * 4000) }
                        SequentialAnimation {
                            loops: Animation.Infinite
                            NumberAnimation {
                                from: 1; to: 0.15
                                duration: 2000 + Math.round(Math.random() * 3000)
                                easing.type: Easing.SineCurve
                            }
                        }
                    }
                }
            }
        }
        Emitter {
            system: sys
            x: 0
            y: 0
            width: root.width
            height: root.height * 0.58
            lifeSpan: stars.life
            lifeSpanVariation: 4000
            emitRate: stars.count / (stars.life / 1000)
            maximumEmitted: Math.round(stars.count * 1.3)
            startTime: stars.life            // pre-populate so stars are not empty at start
        }
    }

    // ---- sun: flat disc, ink outline, optional single faint halo ring ----
    Item {
        id: sun
        // 0 at noon .. 1 at horizon (relative to HORIZON_Y)
        readonly property real warm: Math.max(0, Math.min(1, (root.sunY - 0.30) / (root.horizonY - 0.30)))
        // vermilion #e2462f by day -> deeper red #b92b22 near horizon
        readonly property color sunColor: Qt.rgba(0.886 - 0.16 * warm, 0.275 - 0.106 * warm, 0.184 - 0.05 * warm, 1)
        readonly property real d: root.unit * 0.075

        x: root.sunX * root.width
        y: root.sunY * root.height
        opacity: root.sunVisible ? 1 : 0
        visible: opacity > 0.005
        Behavior on opacity { NumberAnimation { duration: 8000 } }

        Rectangle {   // halo ring, flat
            width: sun.d * 1.7; height: width; radius: width / 2
            x: -width / 2; y: -height / 2
            color: Qt.alpha(sun.sunColor, 0.15)
        }
        Rectangle {   // disc
            width: sun.d; height: width; radius: width / 2
            x: -width / 2; y: -height / 2
            color: sun.sunColor
            border.color: root.ink
            border.width: root.lineW
        }
    }

    // ---- moon: flat cream disc, ink outline, phase via lit Shape ----
    Item {
        id: moon
        readonly property real r: root.unit * 0.03
        readonly property real theta: 2 * Math.PI * root.moonPhase
        readonly property real c: Math.cos(theta)               // 1 new, -1 full
        readonly property bool waxing: root.moonPhase < 0.5

        x: root.moonX * root.width
        y: root.moonY * root.height
        opacity: root.moonVisible ? 1 : 0
        visible: opacity > 0.005
        Behavior on opacity { NumberAnimation { duration: 8000 } }

        Rectangle {   // dark side: band colour lifted slightly toward cream
            width: moon.r * 2; height: width; radius: moon.r
            x: -moon.r; y: -moon.r
            color: Qt.tint(root._band, Qt.rgba(0.97, 0.94, 0.85, 0.14))
        }

        Shape {   // lit part (outer half arc + elliptical terminator)
            x: -moon.r; y: -moon.r
            width: moon.r * 2; height: width
            preferredRendererType: Shape.CurveRenderer

            ShapePath {   // waxing = right side lit
                strokeColor: "transparent"
                fillColor: "#f7f0d8"
                startX: moon.r; startY: 0
                PathArc {
                    x: moon.r; y: moon.r * 2; radiusX: moon.r; radiusY: moon.r
                    direction: moon.waxing ? PathArc.Clockwise : PathArc.Counterclockwise
                }
                PathArc {   // terminator, bottom -> top
                    x: moon.r; y: 0
                    radiusX: Math.max(0.01, moon.r * Math.abs(moon.c)); radiusY: moon.r
                    direction: ((moon.c > 0) === moon.waxing) ? PathArc.Counterclockwise : PathArc.Clockwise
                }
            }
        }

        Rectangle {   // ink outline around the whole disc
            width: moon.r * 2; height: width; radius: moon.r
            x: -moon.r; y: -moon.r
            color: "transparent"
            border.color: root.ink
            border.width: root.lineW
        }
    }
}
