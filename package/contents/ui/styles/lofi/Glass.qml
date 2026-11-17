import QtQuick
import QtQuick.Shapes
import QtQuick.Particles
import "geometry.js" as Geo

// Everything on the window glass: snow on the outer ledge, faint glints, condensation,
// frost, and raindrops that bead, slide down and leave wet trails. Whatever falls outside
// the panes is hidden by the frame drawn on top.
Item {
    id: root

    property var lay: Geo.layout(1920, 1080)
    property real rain: 0
    property real snow: 0
    property real fog: 0
    property color mist: "#f2f4f8"
    property color glint: "white"
    property color snowColor: "#f6f8ff"
    property real lights: 0
    property bool running: true

    readonly property real sh: lay.o                          // outside scale, see layout
    readonly property real gb: lay.glass.y + lay.glass.h      // bottom edge of the glass
    readonly property real area: lay.glass.w * lay.glass.h / (sh * sh)

    Shape {   // drifts on the outer ledge grow with snowfall
        anchors.fill: parent
        visible: root.snow > 0.02
        preferredRendererType: Shape.CurveRenderer
        transform: Scale {
            origin.y: root.gb
            yScale: Math.min(1, root.snow * 1.4)
        }
        ShapePath {
            strokeColor: "transparent"
            fillColor: root.snowColor
            PathSvg { path: Geo.ledge(root.lay) }
        }
    }

    Shape {   // slanted glints, fainter at night
        anchors.fill: parent
        opacity: 0.05 - 0.02 * root.lights
        ShapePath {
            strokeColor: "transparent"
            fillColor: root.glint
            PathSvg { path: Geo.reflections(root.lay) }
        }
    }

    Rectangle {   // condensation, heavier towards the bottom
        x: root.lay.glass.x
        y: root.lay.glass.y
        width: root.lay.glass.w
        height: root.lay.glass.h
        opacity: Math.min(0.55, root.fog * 0.3 + root.rain * 0.14 + root.snow * 0.1)
        visible: opacity > 0.01
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(root.mist, 0.4) }
            GradientStop { position: 1; color: root.mist }
        }
    }

    Item {   // frost: crystals from the edges and a frosted band along the bottom
        anchors.fill: parent
        opacity: Math.min(1, root.snow * 1.5)
        visible: opacity > 0.01

        Rectangle {
            x: root.lay.glass.x
            y: root.gb - root.sh * 0.09
            width: root.lay.glass.w
            height: root.sh * 0.09
            gradient: Gradient {
                GradientStop { position: 0; color: "#00e8f2ff" }
                GradientStop { position: 1; color: "#59e8f2ff" }
            }
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "#b3e8f2ff"
                strokeWidth: Math.max(1, root.sh * 0.0009)
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathSvg { path: Geo.frost(root.lay) }
            }
        }
    }

    // ---- raindrops ----
    // Keep the system running when the rain stops: a stopped system freezes its particles,
    // while a running one lets the last drops shrink and fade.
    ParticleSystem {
        id: sys
        paused: !root.running
    }

    ImageParticle {   // beads and trail droplets
        system: sys
        groups: ["bead", "trail"]
        source: "drop.png"
        alpha: 0.85
        entryEffect: ImageParticle.Fade
    }
    ImageParticle {
        system: sys
        groups: ["slide"]
        source: "slide.png"
        alpha: 0.95
        entryEffect: ImageParticle.Fade
    }

    Emitter {   // drops landing on the glass; they evaporate slowly, so the glass dries after the rain
        system: sys
        group: "bead"
        enabled: root.rain > 0.02
        x: root.lay.glass.x
        y: root.lay.glass.y
        width: root.lay.glass.w
        height: root.lay.glass.h
        emitRate: 18 * root.area * root.rain
        lifeSpan: 24000
        lifeSpanVariation: 10000
        size: root.sh * 0.0072
        sizeVariation: root.sh * 0.004
        endSize: root.sh * 0.0025
    }

    Emitter {   // heavy drops that run down the lower panes
        system: sys
        group: "slide"
        enabled: root.rain > 0.15
        readonly property real fromY: root.lay.transomY + root.lay.m
        x: root.lay.glass.x
        y: fromY
        width: root.lay.glass.w
        height: (root.gb - fromY) * 0.55
        emitRate: 1.2 * root.lay.n * root.rain
        lifeSpan: 7000
        lifeSpanVariation: 3000
        size: root.sh * 0.012
        sizeVariation: root.sh * 0.004
        velocity: AngleDirection {
            angle: 90
            angleVariation: 4
            magnitude: root.sh * 0.05
            magnitudeVariation: root.sh * 0.03
        }
    }

    TrailEmitter {   // the wet trail a running drop leaves behind
        system: sys
        group: "trail"
        follow: "slide"
        emitRatePerParticle: 12
        lifeSpan: 9000
        lifeSpanVariation: 3000
        size: root.sh * 0.0035
        sizeVariation: root.sh * 0.0015
        endSize: root.sh * 0.0012
    }

    Wander {
        system: sys
        groups: ["slide"]
        xVariance: root.sh * 0.01
        pace: root.sh * 0.03
    }
}
