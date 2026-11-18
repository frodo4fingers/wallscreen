pragma ComponentBehavior: Bound
import QtQuick

// Sunlit Ocean: a painting of the open sea between cloud banks, brought to life with slow,
// quiet motion. Small clouds drift over the water with their shadows, glints on the sun's path
// brighten and fade, and the sun rays sway and breathe. The painting itself never moves (resampling a
// detailed picture every frame makes it shimmer), and the cloud layer on top is a cut-out of
// the same painting, so the shadows of the drifting clouds only fall on the sea. Fixed sunny
// day: weather and time are ignored on purpose; only world.running is read.
Item {
    id: scene

    property var world: null
    readonly property bool running: world?.running ?? false

    // the painting's own size; the art is scaled and centred like PreserveAspectCrop, and every
    // overlay is placed in fractions of it
    readonly property real iw: 3876
    readonly property real ih: 1624
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

    clip: true

    Item {
        id: art
        width: scene.iw * scene.k
        height: scene.ih * scene.k
        x: (scene.width - width) / 2
        y: (scene.height - height) / 2

        Image {
            anchors.fill: parent
            source: "ocean.jpg"
            sourceSize: Qt.size(Math.round(art.width), Math.round(art.height))
            smooth: true
        }

        // Small clouds cut from the painting drift over the open water:
        // [height, scale, crossings per 20 min, phase, sprite, sprite width in painting px, mirrored].
        // Each fades in and out at the ends of its path. Its shadow is drawn under the painted
        // cloud banks, so it only falls on the sea; the cloud itself floats above everything.
        readonly property var drifts: [[0.42, 1.0, 4, 0.0, "puff1.png", 340, false], [0.56, 1.25, 3, 0.35, "puff2.png", 280, false],
                                       [0.35, 0.85, 5, 0.6, "puff3.png", 210, false], [0.63, 1.3, 4, 0.8, "puff2.png", 280, true]]
        component Drift: Item {
            required property int index
            readonly property var modelData: art.drifts[index]
            readonly property real u: (scene.clock * modelData[2] + modelData[3]) % 1
            readonly property real fade: Math.min(1, Math.sin(Math.PI * u) * 2.5)
            readonly property real w: art.width * modelData[5] / scene.iw * modelData[1] * (0.9 + 0.2 * u)
            x: art.width * (0.24 + 0.54 * u)
            y: art.height * (modelData[0] + 0.05 * u)
        }

        Repeater {
            model: art.drifts.length
            Drift {
                id: shadow
                Image {
                    source: "shade.png"
                    width: shadow.w * 1.1
                    height: width * 0.4
                    x: -width / 2 + shadow.w * 0.1
                    y: art.height * 0.045 * shadow.modelData[1] - height / 2
                    opacity: 0.22 * shadow.fade
                    smooth: true
                }
            }
        }

        Image {
            anchors.fill: parent
            source: "clouds.webp"
            sourceSize: Qt.size(Math.round(art.width), Math.round(art.height))
            smooth: true
        }

        Repeater {
            model: art.drifts.length
            Drift {
                id: puff
                Image {
                    source: puff.modelData[4]
                    mirror: puff.modelData[6]
                    width: puff.w
                    height: width * implicitHeight / Math.max(1, implicitWidth)
                    x: -width / 2
                    y: -height / 2
                    opacity: puff.fade
                    smooth: true
                }
            }
        }

        // glints on the sun's path: four groups that slowly brighten and fade, 5 to 11 s apart
        Repeater {
            model: 4
            Item {
                id: glints
                required property int index
                anchors.fill: parent
                // 113, 151, 173, 229 cycles per 20 min
                opacity: 0.1 + 0.8 * Math.pow(0.5 + 0.5 * Math.sin(2 * Math.PI * (scene.clock * [113, 151, 173, 229][index] + index / 4)), 2)

                // positions are fixed per group: a cone that widens from the horizon downward
                readonly property var spots: {
                    const out = [];
                    const r = i => { const s = Math.sin(i * 12.9898 + glints.index * 78.233) * 43758.5453; return s - Math.floor(s); };
                    for (let i = 0; i < 40; i++) {
                        const t = Math.pow(r(i * 3 + 1), 0.8);
                        const hw = 0.015 + 0.06 * t;
                        out.push({ x: 0.668 - 0.012 * t + (r(i * 3 + 2) - 0.5) * 2 * hw, y: 0.26 + 0.5 * t,
                                   s: (0.6 + 0.8 * r(i * 3 + 3)) * (0.6 + 0.6 * t) });
                    }
                    return out;
                }

                Repeater {
                    model: glints.spots
                    Image {
                        required property var modelData
                        source: "spark.png"
                        width: art.width * 0.02 * modelData.s
                        height: width
                        x: art.width * modelData.x - width / 2
                        y: art.height * modelData.y - height / 2
                        smooth: true
                    }
                }
            }
        }

        // sun rays: sway about 3 degrees every 92 s and breathe every 40 s
        Image {
            source: "rays.png"
            width: art.height * 1.3
            height: width
            x: art.width * 0.672 - width / 2
            y: art.height * 0.02 - height / 2
            rotation: 3 * Math.sin(2 * Math.PI * scene.clock * 13)
            opacity: 0.3 + 0.14 * Math.sin(2 * Math.PI * scene.clock * 30)
            smooth: true
        }
    }
}
