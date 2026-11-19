import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "geometry.js" as Geo
import "palette.js" as Pal

// Lofi Window: a cosy room window looking out over a city. Reads everything from `world`
// (see README.md, "Writing a style"). Shapes come from geometry.js, colours from palette.js.
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

    // One slow clock, 0..1 every 20 min, drives drift, twinkle, sway and flicker. A timer ticks
    // it 25 times a second instead of an animation at display rate: every tick redraws the
    // scene, and the room moves slowly. 30000 ticks make the 20 min, so it wraps exactly;
    // anything that repeats a whole number of times per cycle wraps without a jump.
    property int ticks: 0
    readonly property real clock: ticks / 30000
    Timer {
        interval: 40
        repeat: true
        running: scene.running
        onTriggered: {
            scene.ticks = (scene.ticks + 1) % 30000;
            if (outside.blurred && scene.ticks % 5 === 0)
                outsideShot.scheduleUpdate();
        }
    }

    Item {
        id: outside
        anchors.fill: parent

        // wet or foggy glass softens everything behind it
        readonly property real blur: Math.min(1, scene.rain * 0.5 + scene.fog * 0.45)
        readonly property bool blurred: blur > 0.02
        onBlurredChanged: if (blurred) outsideShot.scheduleUpdate()

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
            clock: scene.clock
            running: scene.running
        }
    }

    // The view behind wet or foggy glass, blurred. While the wallpaper runs it is captured on every
    // fifth clock tick (5 times a second), not on every change: each new capture costs an extra
    // frame while the blur passes catch up, and behind wet glass the coarser motion does not show.
    // While paused it follows changes directly, which then come only once a minute or so.
    ShaderEffectSource {
        id: outsideShot
        anchors.fill: parent
        sourceItem: outside
        hideSource: outside.blurred
        live: !scene.running
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: outsideShot
        visible: outside.blurred
        autoPaddingEnabled: false
        blurEnabled: true
        blur: outside.blur
        blurMax: 24
    }

    property real flashAt: -1      // clock value when the last bolt struck, -1 = none yet
    // a bolt: a quick double flicker over 0.6 s, sampled on the clock like everything else
    readonly property real flashLevel: {
        const t = flashAt < 0 ? -1 : ((clock - flashAt + 1) % 1) * 1200;
        if (t < 0 || t >= 0.6) return 0;
        const k = [[0, 0], [0.06, 0.7], [0.17, 0.05], [0.22, 0.45], [0.6, 0]];
        let i = 1;
        while (t > k[i][0]) i++;
        return k[i - 1][1] + (k[i][1] - k[i - 1][1]) * (t - k[i - 1][0]) / (k[i][0] - k[i - 1][0]);
    }

    // lightning brightens the sky; it stays out of the captured view, so every flash shows at full rate
    Rectangle {
        id: flash
        x: scene.lay.win.x
        y: scene.lay.win.y
        width: scene.lay.win.w
        height: scene.lay.win.h
        color: "#eef0ff"
        opacity: scene.flashLevel
        visible: opacity > 0
    }

    // in front of the blurred view, so the streaks stay sharp and move at the full clock rate
    Rain {
        anchors.fill: parent
        lay: scene.lay
        rain: scene.rain
        snow: scene.snow
        windX: scene.windX
        rainColor: scene.sky.rain
        snowColor: scene.sky.snow
        clock: scene.clock
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
        clock: scene.clock
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
        clock: scene.clock
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

    // random gap between bolts; the handler only sets the start mark
    Timer {
        repeat: false
        running: scene.storm > 0.3 && scene.running
        interval: 8000
        onTriggered: {
            scene.flashAt = scene.clock;
            interval = 6000 + Math.random() * 14000;
            restart();
        }
    }
}
