// Smoke test: loads the Plasma wallpaper scene components so QML syntax and type
// errors show up without Plasma.
// Run with: QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/tst_smoke.qml
import QtQuick
import QtTest
import "../package/contents/ui"
import "../package/contents/ui/logic.js" as Logic

Item {
    id: scene
    width: 1920
    height: 1080

    Component { id: skyComp; Sky {} }
    Component { id: cloudsComp; Clouds {} }
    Component { id: landscapeComp; Landscape {} }
    Component { id: precipComp; Precipitation {} }
    Component { id: paperComp; Paper {} }
    Component { id: weatherComp; Weather {} }

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
            var c = Logic.skyColors(0.5, 0.3)
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
                colors: Logic.season(new Date(), 50),
                snowCap: 0.4,
                ink: Logic.INK
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
