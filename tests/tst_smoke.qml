// Smoke test: loads the Plasma wallpaper scene components so QML syntax and type
// errors show up without Plasma.
// Run with: QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/tst_smoke.qml
import QtQuick
import QtTest
import "../package/contents/ui"
import "../package/contents/ui/styles/woodblock"
import "../package/contents/ui/styles/woodblock/palette.js" as Palette

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
