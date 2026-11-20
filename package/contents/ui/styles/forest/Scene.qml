pragma ComponentBehavior: Bound
import QtQuick

// Misty Forest: a painting of spruce forest in the fog, brought to life with slow, quiet motion.
// Two layers of mist drift in opposite directions behind the dark front trees, the valley mist
// breathes, a pale glow wanders behind the haze, and a thin low wisp crosses in front of the
// trunks. The painting itself never moves (resampling a detailed picture every frame makes it
// shimmer), and the front trees are a cut-out of the same painting, so the valley mist passes
// behind them. Weather is ignored on purpose; only world.running and world.elevation are read,
// and the elevation only tints the whole scene: navy at night, a warm wash at twilight, clear by
// day; the glow fades out at night.
Item {
    id: scene

    property var world: null
    readonly property bool running: world?.running ?? false

    // the painting's own size; the art is scaled and centred like PreserveAspectCrop, and every
    // overlay is placed in fractions of it
    readonly property real iw: 3360
    readonly property real ih: 1408
    readonly property real k: Math.max(width / iw, height / ih)

    // One slow clock, 0..1 every 20 min. Everything here moves slowly, so it ticks 12.5 times a
    // second, two steps at a time; 30000 steps make the 20 min, and anything that repeats a whole
    // number of times per cycle wraps without a jump.
    property int ticks: 0
    readonly property real clock: ticks / 30000
    Timer {
        interval: 80
        repeat: true
        running: scene.running
        onTriggered: scene.ticks = (scene.ticks + 2) % 30000
    }

    // sun elevation (-1..1), rounded so the tint and the glow change a few times an hour
    // instead of every tick
    readonly property real tone: Math.round((world?.elevation ?? 0.5) * 200) / 200
    readonly property real daylight: Math.max(0, Math.min(1, (tone + 0.1) / 0.3))

    // Colour laid over the whole scene as a pure function of the tone: night navy up to -0.15,
    // warm peach at twilight around 0, clear from 0.2 on, blended linearly in between.
    function tint(t) {
        if (t <= -0.15)
            return Qt.rgba(0.078, 0.118, 0.196, 0.5);
        if (t < 0) {
            const f = (t + 0.15) / 0.15;
            return Qt.rgba(0.078 + f * (1.0 - 0.078), 0.118 + f * (0.69 - 0.118),
                           0.196 + f * (0.502 - 0.196), 0.5 + f * (0.12 - 0.5));
        }
        if (t < 0.2)
            return Qt.rgba(1.0, 0.69, 0.502, 0.12 * (1 - t / 0.2));
        return Qt.rgba(1.0, 0.69, 0.502, 0);
    }

    clip: true

    Item {
        id: art
        width: scene.iw * scene.k
        height: scene.ih * scene.k
        x: (scene.width - width) / 2
        y: (scene.height - height) / 2

        // Two copies of a seamless mist texture side by side, so moving the group by one art
        // width and wrapping looks like an endless band. Only the group's x changes.
        component Band: Item {
            id: band
            property url tex
            property bool flip: false
            Image {
                width: art.width
                height: band.height
                source: band.tex
                mirror: band.flip
                smooth: true
            }
            Image {
                x: art.width
                width: art.width
                height: band.height
                source: band.tex
                mirror: band.flip
                smooth: true
            }
        }

        Image {
            anchors.fill: parent
            source: "forest.jpg"
            sourceSize: Qt.size(Math.round(art.width), Math.round(art.height))
            smooth: true
        }

        // pale glow that wanders slowly behind the mist: one lap sideways and two up and down
        // per cycle
        Image {
            source: "glow.png"
            width: art.height * 0.45
            height: width
            x: art.width * (0.55 + 0.2 * Math.sin(2 * Math.PI * scene.clock)) - width / 2
            y: art.height * (0.475 + 0.125 * Math.sin(2 * Math.PI * (scene.clock * 2 + 0.25))) - height / 2
            opacity: 0.45 * scene.daylight
            smooth: true
        }

        // back mist, six crossings per cycle (about 17 px/s on a 3440 px screen)
        Band {
            tex: "mist2.png"
            y: art.height * 0.05
            height: art.height * 0.6
            x: -((scene.clock * 6) % 1) * art.width
            opacity: 0.9
        }

        // valley mist, ten crossings the other way, breathing every 67 s
        Band {
            tex: "mist1.png"
            y: art.height * 0.2
            height: art.height * 0.6
            x: ((scene.clock * 10) % 1) * art.width - art.width
            opacity: 0.5 + 0.5 * (0.5 + 0.5 * Math.sin(2 * Math.PI * scene.clock * 18))
        }

        Image {
            anchors.fill: parent
            source: "front.png"
            sourceSize: Qt.size(Math.round(art.width), Math.round(art.height))
            smooth: true
        }

        // low wisp in front of the trunks, fourteen crossings per cycle
        Band {
            tex: "mist1.png"
            flip: true
            y: art.height * 0.62
            height: art.height * 0.35
            x: -((scene.clock * 14) % 1) * art.width
            opacity: 0.3
        }
    }

    // time of day: navy at night, peach at twilight, nothing by day; steps with the tone
    Rectangle {
        anchors.fill: parent
        color: scene.tint(scene.tone)
    }
}
