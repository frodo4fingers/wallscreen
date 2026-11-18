pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import "geometry.js" as Geo

// Rain streaks and snowflakes falling past the window, outside the glass. No particles: each
// depth layer is one static sheet of geometry, a little taller than the window, that slides down
// on the shared clock and wraps after a whole number of periods per cycle. Two copies of the
// sheet, one period apart, make the wrap seamless: when the first has fallen one period, it
// lands exactly where the second started. Far and near sheets fade in as it rains or snows
// harder, so the density follows the weather without regenerating anything. The wind slant is
// quantised, so the geometry only rebuilds when it changes by a step. Whatever falls outside the
// window is hidden by the wall drawn on top.
Item {
    id: root

    property var lay: Geo.layout(1920, 1080)
    property real clock: 0
    property real rain: 0
    property real snow: 0
    property real windX: 0
    property color rainColor: "#dfe6f0"
    property color snowColor: "#f6f8ff"

    readonly property real sheetTop: lay.win.y - lay.o * 0.1       // where a sheet starts to show
    readonly property real slantR: Math.round(windX * 0.35 * 20) / 20
    readonly property real slantS: Math.round(windX * 0.6 * 20) / 20

    Repeater {   // rain: mid, far and near sheets
        model: 3
        Item {
            id: sheet
            required property int index
            readonly property var g: Geo.rainSheet(root.lay, index, root.slantR)
            readonly property real u: ((root.clock * g.k) % 1) * g.period
            x: root.slantR * (u - g.period)
            y: root.sheetTop + u - g.period
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
                        fillColor: Qt.alpha(root.rainColor, [0.5, 0.35, 0.6][sheet.index])
                        fillRule: ShapePath.WindingFill
                        PathSvg { path: sheet.g.d }
                    }
                }
            }
        }
    }

    Repeater {   // snow: three depths, two sheets each, with their own sway
        model: 6
        Item {
            id: flakes
            required property int index
            readonly property var g: Geo.snowSheet(root.lay, index, root.slantS)
            readonly property real u: ((root.clock * g.k) % 1) * g.period
            x: root.slantS * (u - g.period) + g.amp * Math.sin(2 * Math.PI * (root.clock * g.m + g.ph))
            y: root.sheetTop + u - g.period
            opacity: Math.max(0, Math.min(1, root.snow * 6 - index))
            visible: opacity > 0.01

            Repeater {
                model: 2
                Shape {
                    required property int index
                    x: index * root.slantS * flakes.g.period
                    y: index * flakes.g.period
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: Qt.alpha(root.snowColor, [0.85, 0.6, 0.95][flakes.index % 3])
                        fillRule: ShapePath.WindingFill
                        PathSvg { path: flakes.g.d }
                    }
                }
            }
        }
    }
}
