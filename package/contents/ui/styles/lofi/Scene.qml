import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "geometry.js" as Geo
import "palette.js" as Pal

// Lofi Window: a cosy room window looking out over a city. Reads everything from `world`
// (see tasks/todo.md, Scene contract). Shapes come from geometry.js, colours from palette.js.
Item {
    id: scene

    property var world: null

    // all defaults apply until world is bound
    readonly property real elevation: world?.elevation ?? 0.3
    readonly property real clouds: world?.clouds ?? 0
    readonly property real rain: world?.rain ?? 0
    readonly property real snow: world?.snow ?? 0
    readonly property real fog: world?.fog ?? 0
    readonly property real storm: world?.storm ?? 0
    readonly property real windX: world?.windX ?? 0
    readonly property bool running: world?.running ?? false
    readonly property bool instant: world?.instant ?? false

    // geometry loops step by fractions of the height, so it never sees a zero size
    readonly property var lay: Geo.layout(Math.max(width, 64), Math.max(height, 36))
    // Elevation and clouds glide continuously; colours follow them in small steps, so the
    // hundreds of shapes recolour every minute or two instead of every frame.
    readonly property real tone: Math.round(elevation * 200) / 200
    readonly property real overcast: Math.round(clouds * 50) / 50
    readonly property var sky: Pal.sky(tone, overcast)
    readonly property var room: Pal.room(tone, overcast)
    readonly property real lights: Pal.lights(tone, overcast)
    readonly property real lamp: Pal.lamp(tone, overcast)

    // One slow clock, 0..1 every 20 min, drives drift, twinkle and flicker. Anything that
    // repeats a whole number of times per cycle wraps without a jump.
    property real clock: 0
    NumberAnimation on clock {
        from: 0
        to: 1
        duration: 1200000
        loops: Animation.Infinite
        running: true
        paused: running && !scene.running
    }

    Item {
        id: outside
        anchors.fill: parent

        // wet or foggy glass softens everything behind it
        readonly property real blur: Math.min(1, scene.rain * 0.5 + scene.fog * 0.45)
        layer.enabled: blur > 0.02
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: outside.blur
            blurMax: 24
        }

        Sky {
            anchors.fill: parent
            lay: scene.lay
            sky: scene.sky
            clock: scene.clock
            lights: scene.lights
            clouds: scene.clouds          // only opacities: keep it smooth
            sunX: scene.world?.sunX ?? 0.3
            sunY: scene.world?.sunY ?? 0.3
            moonX: scene.world?.moonX ?? 0.7
            moonY: scene.world?.moonY ?? 0.3
            sunVisible: scene.world?.sunVisible ?? true
            moonVisible: scene.world?.moonVisible ?? false
            moonPhase: scene.world?.moonPhase ?? 0.5
            starOpacity: scene.world?.starOpacity ?? 0
            running: scene.running
            instant: scene.instant
        }

        City {
            anchors.fill: parent
            lay: scene.lay
            near: false
            body: scene.sky.far
            glass: scene.sky.farGlass
            lights: scene.lights
            clock: scene.clock
            running: scene.running
        }

        Rectangle {   // atmospheric haze between the skyline layers, thick in fog
            x: scene.lay.win.x
            y: scene.lay.win.y
            width: scene.lay.win.w
            height: scene.lay.win.h
            color: scene.sky.haze
            opacity: 0.18 + 0.5 * scene.fog
        }

        City {
            anchors.fill: parent
            lay: scene.lay
            near: true
            body: scene.sky.near
            glass: scene.sky.nearGlass
            lights: scene.lights
            clock: scene.clock
            running: scene.running
        }

        Rectangle {   // ground fog in front of the near skyline
            x: scene.lay.win.x
            y: scene.lay.win.y
            width: scene.lay.win.w
            height: scene.lay.win.h
            visible: scene.fog > 0.01
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(scene.sky.haze, 0.2 * scene.fog) }
                GradientStop { position: 1; color: Qt.alpha(scene.sky.haze, 0.6 * scene.fog) }
            }
        }

        Branch {
            anchors.fill: parent
            lay: scene.lay
            month: scene.world?.month ?? 5
            elevation: scene.tone
            overcast: scene.overcast
            snowColor: scene.sky.snow
            windX: scene.windX
            running: scene.running
        }

        Rain {
            anchors.fill: parent
            lay: scene.lay
            rain: scene.rain
            snow: scene.snow
            windX: scene.windX
            rainColor: scene.sky.rain
            snowColor: scene.sky.snow
            running: scene.running
        }

        Rectangle {
            id: flash
            x: scene.lay.win.x
            y: scene.lay.win.y
            width: scene.lay.win.w
            height: scene.lay.win.h
            color: "#eef0ff"
            opacity: 0
            visible: opacity > 0
        }
    }

    Glass {
        anchors.fill: parent
        lay: scene.lay
        rain: scene.rain
        snow: scene.snow
        fog: scene.fog
        mist: scene.room.mist
        glint: scene.room.glint
        snowColor: scene.sky.snow
        lights: scene.lights
        running: scene.running
    }

    Room {
        anchors.fill: parent
        lay: scene.lay
        c: scene.room
        lights: scene.lights
        lamp: scene.lamp
        clock: scene.clock
        now: scene.world?.now ?? new Date()
    }

    Cat {
        anchors.fill: parent
        lay: scene.lay
        fur: scene.room.fur
        rim: scene.room.rim
        shadow: scene.room.shadow
        running: scene.running
    }

    Curtains {
        anchors.fill: parent
        lay: scene.lay
        c: scene.room
        lights: scene.lights
        clock: scene.clock
    }

    Hanger {
        anchors.fill: parent
        lay: scene.lay
        c: scene.room
        clock: scene.clock
    }

    Desk {
        anchors.fill: parent
        lay: scene.lay
        c: scene.room
        lamp: scene.lamp
        lights: scene.lights
        clock: scene.clock
        running: scene.running
    }

    Shape {   // soft vignette, deeper at night
        anchors.fill: parent
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: scene.width / 2
                centerY: scene.height * 0.48
                centerRadius: Math.hypot(scene.width, scene.height) * 0.62
                focalX: scene.width / 2
                focalY: scene.height * 0.48
                GradientStop { position: 0.55; color: Qt.alpha("#1a0f1c", 0) }
                GradientStop { position: 1; color: Qt.alpha("#1a0f1c", 0.22 + 0.22 * scene.lights) }
            }
            PathSvg { path: Geo.rect(0, 0, scene.width, scene.height) }
        }
    }

    Rectangle {   // the room catches a little of each lightning flash
        anchors.fill: parent
        color: "#dfe4ff"
        opacity: flash.opacity * 0.15
        visible: opacity > 0
    }

    SequentialAnimation {
        id: flashAnim
        onStopped: flash.opacity = 0

        NumberAnimation { target: flash; property: "opacity"; to: 0.7; duration: 60 }
        NumberAnimation { target: flash; property: "opacity"; to: 0.05; duration: 110 }
        NumberAnimation { target: flash; property: "opacity"; to: 0.45; duration: 50 }
        NumberAnimation { target: flash; property: "opacity"; to: 0; duration: 380 }
    }

    // random gap between bolts; the interval is set from the handler, never from inside an animation
    Timer {
        repeat: false
        running: scene.storm > 0.3 && scene.running
        interval: 8000
        onTriggered: {
            flashAnim.restart();
            interval = 6000 + Math.random() * 14000;
            restart();
        }
    }
}
