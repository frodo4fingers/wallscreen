import QtQuick
import "palette.js" as Palette

// Woodblock (ukiyo-e) style. Reads everything from `world` (see tasks/todo.md, Scene contract).
Item {
    id: scene

    property var world: null

    // all defaults apply until world is bound
    readonly property real elevation: world?.elevation ?? 0
    readonly property real light: world?.light ?? 1
    readonly property real clouds: world?.clouds ?? 0
    readonly property real storm: world?.storm ?? 0
    readonly property bool running: world?.running ?? false
    readonly property date now: world?.now ?? new Date()
    readonly property real latitude: world?.latitude ?? 0

    readonly property var sky: Palette.skyColors(elevation, clouds)

    // night indigo-grey to cream-white by light, plus a sakura/peach cast in the golden window at the horizon
    readonly property color cloudTint: {
        const lit = Qt.tint("#3a4170", Qt.rgba(0.984, 0.965, 0.914, light));   // #fbf6e9
        const warm = Math.max(0, 1 - Math.abs(elevation - 0.03) / 0.12);
        return Qt.tint(lit, Qt.rgba(0.965, 0.706, 0.604, warm));   // #f6b49a
    }

    // creamy mist by day (cream tinted by the sky), #5a6478 at night
    readonly property color fogColor: Qt.tint("#5a6478", Qt.alpha(Qt.tint("#efe6cf", Qt.alpha(sky.bottom, 0.25)), light))

    Sky {
        anchors.fill: parent
        topColor: scene.sky.top
        bottomColor: scene.sky.bottom
        bandColor: scene.sky.band
        horizonColor: scene.sky.horizon
        horizonAlpha: scene.sky.horizonAlpha
        sunX: scene.world?.sunX ?? 0.5
        sunY: scene.world?.sunY ?? 0.5
        moonX: scene.world?.moonX ?? 0.5
        moonY: scene.world?.moonY ?? 0.5
        sunVisible: scene.world?.sunVisible ?? false
        moonVisible: scene.world?.moonVisible ?? false
        moonPhase: scene.world?.moonPhase ?? 0
        starOpacity: (scene.world?.starOpacity ?? 0) * (1 - scene.clouds)
        running: scene.running
    }

    Clouds {
        anchors.fill: parent
        cover: scene.clouds
        darkness: Math.max(scene.storm, (scene.world?.rain ?? 0) * 0.5)
        windX: scene.world?.windX ?? 0
        tint: scene.cloudTint
        running: scene.running
    }

    Landscape {
        anchors.fill: parent
        colors: Palette.season(scene.now, scene.latitude)
        light: scene.light
        snowCap: Palette.snowCap(scene.now, scene.latitude)
        ink: Palette.INK
        windX: scene.world?.windX ?? 0
        running: scene.running
    }

    Life {
        anchors.fill: parent
        month: scene.world?.month ?? 0
        light: scene.light
        windX: scene.world?.windX ?? 0
        precip: Math.max(scene.world?.rain ?? 0, scene.world?.snow ?? 0)
        running: scene.running
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: scene.height * 0.6
        opacity: (scene.world?.fog ?? 0) * 0.85
        visible: opacity > 0
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(scene.fogColor, 0) }
            GradientStop { position: 0.6; color: scene.fogColor }
            GradientStop { position: 1.0; color: scene.fogColor }
        }
    }

    Precipitation {
        anchors.fill: parent
        rain: scene.world?.rain ?? 0
        snow: scene.world?.snow ?? 0
        windX: scene.world?.windX ?? 0
        running: scene.running
    }

    Rectangle {
        id: flash
        anchors.fill: parent
        color: "white"
        opacity: 0
        visible: opacity > 0

        SequentialAnimation {
            id: flashAnim
            onStopped: flash.opacity = 0

            NumberAnimation { target: flash; property: "opacity"; to: 0.55; duration: 60 }
            NumberAnimation { target: flash; property: "opacity"; to: 0; duration: 120 }
            NumberAnimation { target: flash; property: "opacity"; to: 0.35; duration: 50 }
            NumberAnimation { target: flash; property: "opacity"; to: 0; duration: 300 }
        }
    }

    // random gap between bolts; the interval is set from the handler, never from inside an animation
    Timer {
        id: boltTimer
        repeat: false
        running: scene.storm > 0.3 && scene.running
        interval: 8000
        onTriggered: {
            flashAnim.restart();
            interval = 6000 + Math.random() * 14000;
            restart();
        }
    }

    // washi grain on top of everything (not interactive)
    Paper {
        anchors.fill: parent
        strength: 0.55
    }
}
