// Smoke test: loads the Plasma wallpaper scene components so QML syntax and type
// errors show up without Plasma.
// Run with: QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/tst_smoke.qml
import QtQuick
import QtTest
import "../package/contents/ui"
import "../package/contents/ui/styles/woodblock"
import "../package/contents/ui/styles/woodblock/palette.js" as Palette
import "../package/contents/ui/styles/lofi" as Lofi
import "../package/contents/ui/styles/lofi/geometry.js" as LofiGeo
import "../package/contents/ui/styles/lofi/palette.js" as LofiPal

Item {
    id: scene
    width: 1920
    height: 1080

    Component { id: skyComp; Sky {} }
    Component { id: cloudsComp; Clouds {} }
    Component { id: landscapeComp; Landscape {} }
    Component { id: precipComp; Precipitation {} }
    Component { id: paperComp; Paper {} }
    Component { id: sceneComp; Scene {} }
    Component { id: weatherComp; Weather {} }
    Component { id: lofiComp; Lofi.Scene {} }

    QtObject {
        id: stubWorld
        property date now: new Date()
        property real latitude: 52.52
        property int month: 5
        property real elevation: 0.5
        property real light: 1
        property real sunX: 0.5
        property real sunY: 0.2
        property real moonX: 0.5
        property real moonY: 0.5
        property bool sunVisible: true
        property bool moonVisible: false
        property real moonPhase: 0.5
        property real starOpacity: 0
        property real clouds: 0.5
        property real rain: 1
        property real snow: 1
        property real fog: 0.5
        property real storm: 1
        property real windX: 0.2
        property bool running: true
        property bool instant: false
    }

    TestCase {
        name: "Smoke"
        when: windowShown

        // Portrait, then ultrawide. Let bindings settle after each resize.
        function resizeAll(obj) {
            obj.width = 1080
            obj.height = 1920
            wait(50)
            obj.width = 3440
            obj.height = 1440
            wait(50)
        }

        function test_sky() {
            var c = Palette.skyColors(0.5, 0.3)
            var obj = createTemporaryObject(skyComp, scene, {
                width: 1920, height: 1080,
                topColor: c.top,
                bottomColor: c.bottom,
                bandColor: c.band,
                horizonColor: c.horizon,
                horizonAlpha: c.horizonAlpha,
                sunX: 0.5, sunY: 0.2,
                sunVisible: true
            })
            verify(obj !== null, "Sky failed to create")
            resizeAll(obj)
        }

        function test_clouds() {
            var obj = createTemporaryObject(cloudsComp, scene, {
                width: 1920, height: 1080,
                cover: 0.7,
                windX: 0.3
            })
            verify(obj !== null, "Clouds failed to create")
            resizeAll(obj)
        }

        function test_landscape() {
            var obj = createTemporaryObject(landscapeComp, scene, {
                width: 1920, height: 1080,
                colors: Palette.season(new Date(), 50),
                snowCap: 0.4,
                ink: Palette.INK
            })
            verify(obj !== null, "Landscape failed to create")
            resizeAll(obj)
        }

        function test_precipitation() {
            var obj = createTemporaryObject(precipComp, scene, {
                width: 1920, height: 1080,
                rain: 1,
                snow: 1,
                windX: 0.2
            })
            verify(obj !== null, "Precipitation failed to create")
            resizeAll(obj)
        }

        function test_paper() {
            var obj = createTemporaryObject(paperComp, scene, {
                width: 1920, height: 1080,
                strength: 0.55
            })
            verify(obj !== null, "Paper failed to create")
            resizeAll(obj)
        }

        function test_scene() {
            var obj = createTemporaryObject(sceneComp, scene, {
                width: 1920, height: 1080,
                world: stubWorld
            })
            verify(obj !== null, "Scene failed to create")
            resizeAll(obj)
        }

        function test_scene_null_world() {
            var obj = createTemporaryObject(sceneComp, scene, { width: 1920, height: 1080 })
            verify(obj !== null, "Scene (null world) failed to create")
        }

        function test_lofi_scene() {
            var obj = createTemporaryObject(lofiComp, scene, {
                width: 1920, height: 1080,
                world: stubWorld
            })
            verify(obj !== null, "Lofi scene failed to create")
            resizeAll(obj)
        }

        function test_lofi_scene_null_world() {
            var obj = createTemporaryObject(lofiComp, scene, { width: 1920, height: 1080 })
            verify(obj !== null, "Lofi scene (null world) failed to create")
        }

        // One pane per ~0.9 window height; the cat sits inside the window on every screen.
        function test_lofi_layout() {
            var cases = [[3440, 1440, 3], [1920, 1080, 2], [1080, 1920, 1], [5120, 1440, 3]]
            for (var i = 0; i < cases.length; i++) {
                var L = LofiGeo.layout(cases[i][0], cases[i][1])
                compare(L.n, cases[i][2], "panes for " + cases[i][0] + "x" + cases[i][1])
                compare(L.panes.length, 2 * L.n)
                var cat = LofiGeo.cat(L)
                verify(cat.cx > L.win.x && cat.cx < L.win.x + L.win.w, "cat inside the window")
            }
        }

        // Every draw op names a palette key and holds a finite path, on every screen shape.
        function test_lofi_draw_lists() {
            var c = LofiPal.room(0.3, 0.2)
            var sizes = [[3440, 1440], [1920, 1080], [1080, 1920], [5120, 1440], [1600, 1200]]
            for (var i = 0; i < sizes.length; i++) {
                var L = LofiGeo.layout(sizes[i][0], sizes[i][1]), d = LofiGeo.desk(L)
                var lists = [LofiGeo.plant(L).ops, LofiGeo.stack(L), LofiGeo.curtains(L), LofiGeo.garland(L).ops,
                             LofiGeo.shelves(L), LofiGeo.clock(L).ops, LofiGeo.photos(L).ops, LofiGeo.radiator(L),
                             LofiGeo.hanger(L).ops, d.surface, d.items]
                for (var j = 0; j < lists.length; j++) {
                    for (var k = 0; k < lists[j].length; k++) {
                        var o = lists[j][k]
                        verify(c[o.c] !== undefined, "palette key " + o.c)
                        verify(!/NaN|undefined/.test(o.d), "finite path for " + o.c + " at " + sizes[i])
                    }
                }
            }
        }

        function test_lofi_palette() {
            var hex = /^#[0-9a-f]{6}$/
            var es = [-1, -0.1, 0, 0.1, 1]
            for (var i = 0; i < es.length; i++) {
                var s = LofiPal.sky(es[i], 0.6), r = LofiPal.room(es[i], 0.6)
                for (var k in s) verify(hex.test(s[k]), "sky." + k + " " + s[k])
                for (var j in r) verify(hex.test(r[j]), "room." + j + " " + r[j])
            }
            compare(LofiPal.lights(-1, 0), 1)
            compare(LofiPal.lights(1, 0), 0)
            compare(LofiGeo.season(0), 3)   // January: winter
            compare(LofiGeo.season(3), 0)   // April: spring
            compare(LofiGeo.season(9), 2)   // October: autumn
        }

        // Weather only checked for creation. valid stays false until the network
        // answers, and the test does not wait for it.
        function test_weather() {
            var stub = {
                City: "Berlin",
                ResolvedCity: "Berlin",
                Latitude: 52.52,
                Longitude: 13.405,
                CachedWeather: "",
                writeConfig: function () {}
            }
            var obj = createTemporaryObject(weatherComp, scene, {
                cfg: stub,
                city: "Berlin"
            })
            verify(obj !== null, "Weather failed to create")
            compare(obj.valid, false)
        }
    }
}
