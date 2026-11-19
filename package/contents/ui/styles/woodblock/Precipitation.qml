pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import "precip.js" as Precip

// Woodblock look. Rain: long thin parallel ink lines. Snow: flat cream dots with a faint ink
// rim. No particles: each depth layer is one static sheet of geometry, a little taller than the
// screen, that slides down on the shared clock and wraps after a whole number of periods per
// cycle. Two copies of the sheet, one period apart, make the wrap seamless. Far and near sheets
// fade in as it rains or snows harder, so the density follows the weather without regenerating
// anything. The wind slant is quantised, so the geometry only rebuilds on a size change or when
// the slant moves by a step. A sheet that is faded out does not evaluate any per-tick bindings.
Item {
    id: root

    property real clock: 0
    property real rain: 0
    property real snow: 0
    property real windX: 0
    property bool running: true   // unused: the clock stops when the scene is paused

    clip: true

    readonly property real px: Math.max(0.4, Math.min(width, height) / 1080)
    readonly property real slantR: Math.round(0.4 * windX * 20) / 20
    readonly property real slantS: Math.round(0.8 * windX * 20) / 20

    Repeater {   // rain: three sheets, two copies each
        model: 3
        Item {
            id: sheet
            required property int index
            readonly property var g: Precip.rainSheet(root.width, root.height, index, root.slantR)
            readonly property real c: visible ? root.clock : 0
            readonly property real u: ((c * g.k) % 1) * g.period
            x: root.slantR * (u - g.period)
            y: g.top + u - g.period
            opacity: Math.max(0, Math.min(1, root.rain * 3 - index))
            visible: opacity > 0.01

            Repeater {
                model: 2
                Shape {
                    required property int index
                    x: index * root.slantR * sheet.g.period
                    y: index * sheet.g.period
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: "#8c2b3550"   // #2b3550 at ~0.55 alpha
                        fillRule: ShapePath.WindingFill
                        PathSvg { path: sheet.g.d }
                    }
                }
            }
        }
    }

    Repeater {   // snow: three sheets, two copies each, with their own sway
        model: 3
        Item {
            id: flakes
            required property int index
            readonly property var g: Precip.snowSheet(root.width, root.height, index, root.slantS)
            readonly property real c: visible ? root.clock : 0
            readonly property real u: ((c * g.k) % 1) * g.period
            x: root.slantS * (u - g.period) + g.amp * Math.sin(2 * Math.PI * (c * g.m + g.ph))
            y: g.top + u - g.period
            opacity: Math.max(0, Math.min(1, root.snow * 3 - index))
            visible: opacity > 0.01

            Repeater {
                model: 2
                Shape {
                    required property int index
                    x: index * root.slantS * flakes.g.period
                    y: index * flakes.g.period
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: "#591d1a2e"   // ink #1d1a2e at ~0.35 alpha
                        strokeWidth: Math.max(1, root.px * 0.8)
                        fillColor: "#f7f4ec"
                        fillRule: ShapePath.WindingFill
                        PathSvg { path: flakes.g.d }
                    }
                }
            }
        }
    }
}
