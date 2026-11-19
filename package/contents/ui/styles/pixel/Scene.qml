pragma ComponentBehavior: Bound
import QtQuick
import "../lofi/palette.js" as Pal
import "draw.js" as Draw
import "art.js" as Art

// Pixel Loft: a cozy modern loft in pixel art, with a big window onto a city skyline.
// The whole picture is drawn at 576x240 art pixels into one layer and scaled up by a whole
// number with nearest-neighbour sampling, so every art pixel stays a crisp square.
// The view follows time of day and the live weather; the room switches from daylight to
// lamplight. Motion is slow and stepped: drifting clouds, rain or snow, a breathing cat that
// takes a walk along the bench every ten minutes, steam from the mug, and string lights.
Item {
    id: scene

    property var world: null
    readonly property real elevation: world?.elevation ?? 0.3
    readonly property real clouds: world?.clouds ?? 0
    readonly property real rain: world?.rain ?? 0
    readonly property real snow: world?.snow ?? 0
    readonly property real fog: world?.fog ?? 0
    readonly property real storm: world?.storm ?? 0
    readonly property real windX: world?.windX ?? 0
    readonly property bool running: world?.running ?? false

    // the palette changes in small steps, so the canvases repaint rarely
    readonly property real tone: Math.round(elevation * 200) / 200
    readonly property real overcast: Math.round(clouds * 50) / 50
    readonly property var pal: Pal.sky(tone, overcast)
    readonly property real lit: Pal.lights(tone, overcast)
    readonly property real lamp: Pal.lamp(tone, overcast)

    // whole-number scale that covers the screen; the art is centred and cropped
    readonly property int k: Math.max(1, Math.ceil(Math.max(width / 576, height / 240)))

    // 12.5 ticks a second; everything moves in whole steps of this clock
    property int ticks: 0
    Timer {
        interval: 80
        repeat: true
        running: scene.running
        onTriggered: scene.ticks = (scene.ticks + 1) % 1000000000
    }

    readonly property var cat: Draw.catPose(ticks)

    clip: true

    Item {
        id: pix
        width: 576
        height: 240
        x: Math.round((scene.width - width * scene.k) / 2)
        y: Math.round((scene.height - height * scene.k) / 2)
        scale: scene.k
        transformOrigin: Item.TopLeft
        layer.enabled: true
        layer.smooth: false

        // ---- the view through the window -------------------------------------------------
        Item {
            x: Art.GLASS[0]
            y: Art.GLASS[1]
            width: Art.GLASS[2]
            height: Art.GLASS[3]

            Canvas {
                id: sky
                anchors.fill: parent
                // the state object is rebuilt only when one of these values changes, not every tick
                readonly property int starStep: Math.floor(scene.ticks / 40)
                readonly property var state: ({
                    sunVisible: scene.world?.sunVisible ?? true,
                    moonVisible: scene.world?.moonVisible ?? false,
                    sunX: scene.world?.sunX ?? 0.6, sunY: scene.world?.sunY ?? 0.25,
                    moonX: scene.world?.moonX ?? 0.5, moonY: scene.world?.moonY ?? 0.5,
                    moonPhase: scene.world?.moonPhase ?? 0.5,
                    starOpacity: scene.world?.starOpacity ?? 0,
                    starStep: starStep
                })
                onStateChanged: requestPaint()
                Connections { target: scene; function onPalChanged() { sky.requestPaint() } }
                onPaint: Draw.drawSky(getContext("2d"), scene.pal, state)
            }

            Canvas {
                id: cloudLayer
                anchors.fill: parent
                readonly property int step: Math.floor(scene.ticks / 16)
                readonly property real amount: scene.overcast
                onStepChanged: requestPaint()
                onAmountChanged: requestPaint()
                Connections { target: scene; function onPalChanged() { cloudLayer.requestPaint() } }
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    Draw.drawClouds(ctx, scene.pal, amount, step);
                }
            }

            Canvas {
                id: city
                anchors.fill: parent
                readonly property int slot: Math.floor(scene.ticks / 3750)      // every 5 minutes
                readonly property real fogLevel: Math.round(scene.fog * 20) / 20
                onSlotChanged: requestPaint()
                onFogLevelChanged: requestPaint()
                Connections {
                    target: scene
                    function onPalChanged() { city.requestPaint() }
                    function onLitChanged() { city.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    Draw.drawCity(ctx, scene.pal, scene.lit, slot, fogLevel);
                }
            }

            // the warning light on the tower fades on and off every few seconds
            Rectangle {
                x: Draw.SPIRE.x + 1
                y: Draw.SPIRE.top - 1
                width: 1
                height: 2
                color: "#ff4a3a"
                opacity: scene.lit * [1, 0.7, 0.35, 0.15, 0.35, 0.7][Math.floor(scene.ticks / 6) % 6]
            }

            Canvas {
                id: precip
                anchors.fill: parent
                readonly property bool falling: scene.rain > 0.01 || scene.snow > 0.01
                readonly property int tick: falling ? scene.ticks : 0
                onTickChanged: requestPaint()
                onFallingChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    if (falling)
                        Draw.drawPrecip(ctx, scene.pal, scene.rain, scene.snow, scene.windX, tick);
                }
            }

            // a storm brightens the sky softly for a moment, about every 90 s
            Rectangle {
                anchors.fill: parent
                color: "#f0ecff"
                visible: scene.storm > 0.5 && scene.ticks % 1100 < 2
                opacity: 0.15 * scene.storm
            }
        }

        // ---- the room: daylight and lamplight versions crossfade ----------------------------
        Image {
            source: "room_day.png"
            smooth: false
        }
        Image {
            source: "room_night.png"
            smooth: false
            opacity: scene.lamp
        }

        // string lights take turns, slowly, when the lamps are on
        Repeater {
            model: Art.BULBS
            Rectangle {
                required property var modelData
                required property int index
                x: modelData[0]
                y: modelData[1] - 1
                width: 2
                height: 2
                color: "#ffe6a8"
                opacity: scene.lamp * ((index + Math.floor(scene.ticks / 40)) % 2 ? 1 : 0.45)
            }
        }

        // steam from the mug: a few pixels rise and fade
        Repeater {
            model: 4
            Rectangle {
                required property int index
                readonly property int phase: (scene.ticks + index * 9) % 36
                x: Art.MUG[0] + [0, 1, 1, 0, -1, -1][Math.floor(phase / 6)]
                y: Art.MUG[1] - Math.floor(phase / 3)
                width: 1
                height: 1
                color: "#ece6f6"
                opacity: 0.55 * (1 - phase / 36)
            }
        }

        // ---- the cat ------------------------------------------------------------------------
        Item {
            x: Art.CAT_BOX[0]
            y: Art.CAT_BOX[1]
            width: Art.CAT_SIZE[0]
            height: Art.CAT_SIZE[1]
            visible: scene.cat.sleep
            readonly property int breath: Math.floor(scene.ticks / 25) % 2
            Image {
                source: "cat_day.png"
                smooth: false
                sourceClipRect: Qt.rect(parent.breath * Art.CAT_SIZE[0], 0, Art.CAT_SIZE[0], Art.CAT_SIZE[1])
            }
            Image {
                source: "cat_night.png"
                smooth: false
                opacity: scene.lamp
                sourceClipRect: Qt.rect(parent.breath * Art.CAT_SIZE[0], 0, Art.CAT_SIZE[0], Art.CAT_SIZE[1])
            }
        }
        Item {
            x: scene.cat.x
            y: Art.WALK_Y
            width: Art.WALK_SIZE[0]
            height: Art.WALK_SIZE[1]
            visible: !scene.cat.sleep
            Image {
                source: "cat_walk_day.png"
                smooth: false
                mirror: scene.cat.left
                sourceClipRect: Qt.rect(scene.cat.frame * Art.WALK_SIZE[0], 0, Art.WALK_SIZE[0], Art.WALK_SIZE[1])
            }
            Image {
                source: "cat_walk_night.png"
                smooth: false
                mirror: scene.cat.left
                opacity: scene.lamp
                sourceClipRect: Qt.rect(scene.cat.frame * Art.WALK_SIZE[0], 0, Art.WALK_SIZE[0], Art.WALK_SIZE[1])
            }
        }
    }
}
