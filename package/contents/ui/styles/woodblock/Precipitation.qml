import QtQuick
import QtQuick.Particles

// Woodblock look. Rain: long thin parallel ink lines (ItemParticle, <= 350 alive).
// Snow: flat cream dots with a faint ink rim (ItemParticle, <= 400 alive). No glow.
// No JS runs per frame: rates/velocities are bindings re-evaluated on prop changes only.
Item {
    id: root

    property real rain: 0
    property real snow: 0
    property real windX: 0
    property bool running: true

    // Screen-size scale: area vs 1920x1080 (clamped), and linear size scale.
    readonly property real areaScale: Math.max(0.5, Math.min(1.5, (width * height) / (1920 * 1080)))
    readonly property real px: Math.max(0.4, Math.min(width, height) / 1080)

    // Rain: vertical speed in px/s; horizontal = windX * 0.4 * vertical. One slant for all lines.
    readonly property real rainVy: Math.max(1, height * 1.3)
    readonly property real rainTilt: Math.atan(0.4 * windX) * 180 / Math.PI
    readonly property real rainDx: 0.4 * windX * 1.3 * height // sideways travel over a drop's life

    // Snow: slow fall, drifts more readily than rain.
    readonly property real snowVy: Math.max(1, height * 0.11)
    readonly property real snowDx: 0.8 * windX * 1.3 * height

    property real rainRate: 230 * areaScale * Math.max(0, Math.min(1, rain))
    property real snowRate: 32 * areaScale * Math.max(0, Math.min(1, snow))
    Behavior on rainRate { NumberAnimation { duration: 10000 } }
    Behavior on snowRate { NumberAnimation { duration: 10000 } }

    ParticleSystem {
        id: sys
        paused: !root.running
    }

    // ---- Rain ----
    ItemParticle {
        system: sys
        groups: ["rain"]
        fade: false
        delegate: Item {
            width: 1; height: 1
            // Inner item carries the rotation, since ItemParticle owns the outer item's transform.
            Rectangle {
                // Length picked once per drop (0.08-0.14 of height); not per frame.
                width: Math.max(1, Math.min(root.width, root.height) * 0.0009)
                height: root.height * (0.08 + 0.06 * Math.random())
                x: -width / 2
                y: -height / 2
                rotation: -root.rainTilt
                color: "#8c2b3550" // #2b3550 at ~0.55 alpha
                antialiasing: true
            }
        }
    }
    Emitter {
        system: sys
        group: "rain"
        enabled: root.rainRate > 0.5
        emitRate: root.rainRate
        lifeSpan: 1000 * 1.2 * root.height / root.rainVy
        maximumEmitted: 350
        // Full width plus an upwind margin, above the top edge (lines are up to 0.14 tall).
        x: -Math.max(0, root.rainDx)
        y: -0.1 * root.height
        width: root.width + Math.abs(root.rainDx)
        height: 1
        velocity: PointDirection {
            x: 0.4 * root.windX * root.rainVy
            y: root.rainVy
            yVariation: 0.05 * root.rainVy
        }
    }

    // ---- Snow ----
    ItemParticle {
        system: sys
        groups: ["snow"]
        fade: false
        delegate: Item {
            width: 1; height: 1
            Rectangle {
                // Diameter picked once per flake: 0.004-0.011 of the short side.
                width: Math.min(root.width, root.height) * (0.004 + 0.007 * Math.random())
                height: width
                x: -width / 2
                y: -height / 2
                radius: width / 2
                color: "#f7f4ec"
                border.color: "#591d1a2e" // ink #1d1a2e at ~0.35 alpha
                border.width: Math.max(1, root.px * 0.8)
                antialiasing: true
            }
        }
    }
    Emitter {
        system: sys
        group: "snow"
        enabled: root.snowRate > 0.5
        emitRate: root.snowRate
        lifeSpan: 1000 * 1.3 * root.height / root.snowVy
        maximumEmitted: 400
        x: -Math.max(0, root.snowDx)
        y: -0.03 * root.height
        width: root.width + Math.abs(root.snowDx)
        height: 1
        velocity: PointDirection {
            x: 0.8 * root.windX * root.snowVy
            y: root.snowVy
            xVariation: 0.1 * root.snowVy
            yVariation: 0.2 * root.snowVy
        }
    }
    Wander {
        system: sys
        groups: ["snow"]
        xVariance: 25 * root.px
        pace: 60
    }
}
