import QtQuick
import QtQuick.Shapes
import "geometry.js" as Geo
import "palette.js" as Pal

// The sky through the window: gradient, soft sun and moon with glow, twinkling stars,
// drifting two-tone clouds and now and then a plane.
Item {
    id: root

    property var lay: Geo.layout(1920, 1080)
    property var sky: Pal.sky(0.3, 0)
    property real clock: 0
    property real lights: 0
    property real clouds: 0
    property real sunX: 0.3
    property real sunY: 0.3
    property real moonX: 0.7
    property real moonY: 0.3
    property bool sunVisible: true
    property bool moonVisible: false
    property real moonPhase: 0.5      // 0 new, 0.5 full
    property real starOpacity: 0
    property bool running: true
    property bool instant: false

    // the outside is sized for a window 0.74 of this height tall (see layout)
    readonly property real sh: lay.o

    Rectangle {
        x: root.lay.win.x
        y: root.lay.win.y
        width: root.lay.win.w
        height: root.lay.sillY - y
        gradient: Gradient {
            GradientStop { position: 0; color: root.sky.top }
            GradientStop { position: 0.55; color: root.sky.mid }
            GradientStop { position: 1; color: root.sky.low }
        }
    }

    // ---- stars: three groups twinkling at different rates on the shared clock ----
    Item {
        id: stars
        anchors.fill: parent
        opacity: root.starOpacity * (1 - 0.85 * root.clouds)
        visible: opacity > 0.01

        readonly property var paths: Geo.starPaths(root.lay)

        Repeater {
            model: 3
            Shape {
                id: group
                required property int index
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                // 173, 241, 311 cycles per 20 min: periods of 7, 5 and 4 s
                opacity: 0.6 + 0.4 * Math.sin(2 * Math.PI * (root.clock * [173, 241, 311][index] + index / 3))
                ShapePath {
                    strokeColor: "transparent"
                    fillColor: "#fff6e2"
                    PathSvg { path: stars.paths[group.index] }
                }
            }
        }
    }

    // ---- sun: soft disc in a wide glow ----
    Item {
        id: sun
        readonly property real r: root.sh * 0.03
        readonly property real glowR: r * 7
        readonly property var p: Geo.skyPoint(root.lay, root.sunX, root.sunY)

        x: p[0]
        y: p[1]
        opacity: root.sunVisible ? 1 - 0.8 * root.clouds : 0
        visible: opacity > 0.01
        Behavior on opacity {
            enabled: !root.instant
            NumberAnimation { duration: 6000 }
        }

        Shape {
            x: -sun.glowR
            y: -sun.glowR
            width: sun.glowR * 2
            height: width
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: sun.glowR
                    centerY: sun.glowR
                    centerRadius: sun.glowR
                    focalX: sun.glowR
                    focalY: sun.glowR
                    GradientStop { position: 0; color: Qt.alpha(root.sky.halo, 0.55) }
                    GradientStop { position: 0.25; color: Qt.alpha(root.sky.halo, 0.18) }
                    GradientStop { position: 1; color: Qt.alpha(root.sky.halo, 0) }
                }
                PathSvg { path: Geo.circle(sun.glowR, sun.glowR, sun.glowR) }
            }
        }
        Rectangle {
            x: -sun.r
            y: -sun.r
            width: sun.r * 2
            height: width
            radius: sun.r
            color: root.sky.sun
            antialiasing: true
        }
    }

    // ---- moon: phase via an elliptical terminator, cool glow ----
    Item {
        id: moon
        readonly property real r: root.sh * 0.024
        readonly property real glowR: r * 5
        readonly property real c: Math.cos(2 * Math.PI * root.moonPhase)   // 1 new, -1 full
        readonly property bool waxing: root.moonPhase < 0.5
        readonly property var p: Geo.skyPoint(root.lay, root.moonX, root.moonY)

        x: p[0]
        y: p[1]
        opacity: root.moonVisible ? 1 - 0.8 * root.clouds : 0
        visible: opacity > 0.01
        Behavior on opacity {
            enabled: !root.instant
            NumberAnimation { duration: 6000 }
        }

        Shape {
            x: -moon.glowR
            y: -moon.glowR
            width: moon.glowR * 2
            height: width
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: moon.glowR
                    centerY: moon.glowR
                    centerRadius: moon.glowR
                    focalX: moon.glowR
                    focalY: moon.glowR
                    // glow follows how much of the disc is lit
                    GradientStop { position: 0; color: Qt.rgba(0.79, 0.81, 0.96, 0.08 + 0.25 * (1 - moon.c) / 2) }
                    GradientStop { position: 1; color: Qt.rgba(0.79, 0.81, 0.96, 0) }
                }
                PathSvg { path: Geo.circle(moon.glowR, moon.glowR, moon.glowR) }
            }
        }
        Rectangle {   // dark side, barely lifted from the sky
            x: -moon.r
            y: -moon.r
            width: moon.r * 2
            height: width
            radius: moon.r
            color: Qt.tint(root.sky.top, "#26f3eedf")
            antialiasing: true
        }
        Shape {   // lit part: outer half arc, then the terminator back up
            x: -moon.r
            y: -moon.r
            width: moon.r * 2
            height: width
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillColor: "#f3eedf"
                startX: moon.r
                startY: 0
                PathArc {
                    x: moon.r
                    y: moon.r * 2
                    radiusX: moon.r
                    radiusY: moon.r
                    direction: moon.waxing ? PathArc.Clockwise : PathArc.Counterclockwise
                }
                PathArc {
                    x: moon.r
                    y: 0
                    radiusX: Math.max(0.01, moon.r * Math.abs(moon.c))
                    radiusY: moon.r
                    direction: ((moon.c > 0) === moon.waxing) ? PathArc.Counterclockwise : PathArc.Clockwise
                }
            }
        }
    }

    // ---- clouds: up to 7, more of them the cloudier it is ----
    Repeater {
        model: Geo.clouds(root.lay)
        Shape {
            id: cloud
            required property var modelData
            required property int index

            x: root.lay.win.x - modelData.w + ((modelData.phase + modelData.k * root.clock) % 1) * (root.lay.win.w + modelData.w)
            y: modelData.y
            opacity: Math.max(0, Math.min(1, 1.5 + root.clouds * 5.5 - index))
            visible: opacity > 0
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: "transparent"
                fillColor: root.sky.cloudBottom
                fillRule: ShapePath.WindingFill
                PathSvg { path: cloud.modelData.shadow }
            }
            ShapePath {
                strokeColor: "transparent"
                fillColor: root.sky.cloudTop
                fillRule: ShapePath.WindingFill
                PathSvg { path: cloud.modelData.light }
            }
        }
    }

    // ---- plane: blinking lights at night, a tiny silhouette by day ----
    Item {
        id: plane
        property real dir: 1
        property real t: 0
        property real y0: 0
        readonly property real span: root.lay.win.w + root.sh * 0.04
        readonly property real blink: (root.clock * 1100) % 1      // ~1.1 s

        visible: fly.running
        x: root.lay.win.x - root.sh * 0.02 + (dir > 0 ? t : 1 - t) * span
        y: y0 - t * root.sh * 0.02

        Shape {
            opacity: 1 - root.lights
            preferredRendererType: Shape.CurveRenderer
            transform: Scale { xScale: plane.dir }
            ShapePath {
                strokeColor: "transparent"
                fillColor: root.sky.far
                fillRule: ShapePath.WindingFill
                PathSvg {
                    // fuselage, swept wing, tail fin; nose at +x
                    path: {
                        const s = root.sh * 0.007;
                        return Geo.capsule(-s, -s * 0.12, 2 * s, s * 0.24)
                            + "M" + (-0.2 * s) + " 0 L" + (0.25 * s) + " 0 L" + (-0.35 * s) + " " + (0.5 * s) + " Z "
                            + "M" + (-0.6 * s) + " 0 L" + (-0.95 * s) + " 0 L" + (-1.0 * s) + " " + (-0.45 * s) + " Z";
                    }
                }
            }
        }
        Rectangle {   // red beacon
            width: Math.max(2, root.sh * 0.0028)
            height: width
            radius: width / 2
            x: -width / 2
            y: -height / 2
            color: "#ff5a5a"
            opacity: root.lights * (plane.blink < 0.5 ? 1 : 0.15)
        }
        Rectangle {   // white strobe
            width: Math.max(2, root.sh * 0.0022)
            height: width
            radius: width / 2
            x: plane.dir * root.sh * 0.005 - width / 2
            y: -height / 2
            color: "white"
            opacity: root.lights * (plane.blink > 0.55 && plane.blink < 0.62 ? 1 : 0)
        }
    }

    NumberAnimation {
        id: fly
        target: plane
        property: "t"
        from: 0
        to: 1
        duration: 70000
        paused: running && !root.running
    }

    // random gap between planes; set from the handler, never from inside an animation
    Timer {
        repeat: false
        running: root.running && root.clouds < 0.85
        interval: 25000
        onTriggered: {
            plane.dir = Math.random() < 0.5 ? -1 : 1;
            plane.y0 = root.lay.win.y + root.sh * (0.06 + Math.random() * 0.16);
            fly.duration = 55000 + Math.random() * 30000;
            fly.restart();
            interval = fly.duration + 60000 + Math.random() * 180000;
            restart();
        }
    }
}
