import QtQuick
import QtQuick.Particles
import "geometry.js" as Geo

// Rain streaks and snowflakes falling past the window, outside the glass.
Item {
    id: root

    property var lay: Geo.layout(1920, 1080)
    property real rain: 0
    property real snow: 0
    property real windX: 0
    property color rainColor: "#dfe6f0"
    property color snowColor: "#f6f8ff"
    property bool running: true

    readonly property real sh: lay.o                          // outside scale, see layout
    readonly property real fall: lay.sillY - lay.win.y        // visible drop height
    readonly property real area: Math.max(0.4, Math.min(2.4, lay.win.w * lay.win.h / (1600 * 800)))
    readonly property real rainVy: sh * 1.25
    readonly property real rainVx: windX * 0.35 * rainVy
    readonly property real snowVy: sh * 0.09
    readonly property real snowVx: windX * 0.6 * snowVy
    readonly property real drift: Math.max(Math.abs(rainVx) * fall / rainVy, Math.abs(snowVx) * fall / snowVy)

    // never stopped: a stopped system would freeze the last drops and flakes in mid-air
    ParticleSystem {
        id: sys
        paused: !root.running
    }

    // the streak sprite is horizontal; autoRotation turns it along the velocity
    ImageParticle {
        system: sys
        groups: ["rain"]
        source: "streak.png"
        color: root.rainColor
        alpha: 0.55
        autoRotation: true
    }
    Emitter {
        system: sys
        group: "rain"
        enabled: root.rain > 0.02
        emitRate: 220 * root.area * root.rain
        lifeSpan: 1000 * (root.fall + root.sh * 0.1) / root.rainVy
        size: root.sh * 0.07
        sizeVariation: root.sh * 0.025
        x: root.lay.win.x - (root.rainVx > 0 ? root.drift : 0)
        y: root.lay.win.y - root.sh * 0.05
        width: root.lay.win.w + root.drift
        height: 1
        velocity: PointDirection {
            x: root.rainVx
            y: root.rainVy
            yVariation: root.rainVy * 0.08
        }
    }

    ImageParticle {
        system: sys
        groups: ["snow"]
        source: "flake.png"
        color: root.snowColor
        alpha: 0.9
    }
    Emitter {
        system: sys
        group: "snow"
        enabled: root.snow > 0.02
        emitRate: 70 * root.area * root.snow
        lifeSpan: 1000 * (root.fall + root.sh * 0.05) / root.snowVy
        size: root.sh * 0.006
        sizeVariation: root.sh * 0.004
        x: root.lay.win.x - (root.snowVx > 0 ? root.drift : 0)
        y: root.lay.win.y - root.sh * 0.02
        width: root.lay.win.w + root.drift
        height: 1
        velocity: PointDirection {
            x: root.snowVx
            y: root.snowVy
            xVariation: root.sh * 0.015
            yVariation: root.sh * 0.03
        }
    }
    Wander {
        system: sys
        groups: ["snow"]
        xVariance: root.sh * 0.03
        pace: root.sh * 0.05
    }
}
