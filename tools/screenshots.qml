// Renders README screenshots of every style offscreen, without Plasma.
// Run from the repository root:
//   QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tools/screenshots.qml
// Writes docs/screenshots/<style>-<state>.jpg, or .png for the pixel style, whose flat colours
// compress better and must stay sharp.
import QtQuick
import QtTest
import "../package/contents/ui/logic.js" as Logic

Item {
    id: root
    // half of a 3440x1440 ultrawide, so the framing matches the screen the styles were made on
    width: 1720
    height: 720

    // a world object like main.qml builds, for a fixed hour and weather preset
    function makeWorld(hour, preset) {
        const now = new Date(2026, 5, 21, 0, 0, 0, 0);
        now.setHours(Math.floor(hour), (hour % 1) * 60);
        const cel = Logic.celestial(now, NaN, NaN);
        const ws = Logic.presetWeather(preset);
        return {
            now: now, latitude: 52.52, month: now.getMonth(),
            elevation: cel.elevation, light: Logic.sceneLight(cel.elevation, ws.clouds),
            sunX: cel.sunX, sunY: cel.sunY, moonX: cel.moonX, moonY: cel.moonY,
            sunVisible: cel.sunVisible, moonVisible: cel.moonVisible,
            moonPhase: 0.45, starOpacity: cel.starOpacity,
            clouds: ws.clouds, rain: ws.rain, snow: ws.snow, fog: ws.fog, storm: ws.storm,
            windX: (ws.rain > 0 || ws.snow > 0) ? 0.3 : 0.1,
            running: true, instant: true
        };
    }

    // state name, hour, weather preset (1 clear, 2 cloudy, 3 rain, 4 snow, 5 storm, 6 fog)
    readonly property var states: [
        ["day", 11, 1],
        ["dusk", 17.8, 1],
        ["rain", 14, 3],
        ["night", 22, 4]
    ]
    readonly property var styles: ["woodblock", "lofi", "ocean", "pixel"]

    function statesFor(style) {
        // the ocean painting ignores time and weather, so one picture is enough
        if (style === "ocean")
            return states.slice(0, 1);
        // offscreen Qt Quick uses the software renderer, which cannot run lofi's blur shader
        // behind wet glass, so lofi shows a snowy day instead of rain
        if (style === "lofi")
            return states.map(st => st[0] === "rain" ? ["snow", 13, 4] : st);
        return states;
    }

    Loader {
        id: loader
        anchors.fill: parent
    }

    TestCase {
        name: "Screenshots"
        when: windowShown

        function test_render() {
            for (const style of root.styles) {
                for (const st of root.statesFor(style)) {
                    loader.source = "";
                    // world goes in at creation, so colour Behaviors start at the target instead of fading to it
                    loader.setSource(Qt.resolvedUrl("../package/contents/ui/styles/" + style + "/Scene.qml"),
                                     { world: root.makeWorld(st[1], st[2]) });
                    tryCompare(loader, "status", Loader.Ready);
                    // let particles fill the screen and canvases paint
                    wait(st[2] >= 3 ? 6000 : 2000);
                    const path = "docs/screenshots/" + style + "-" + st[0] + (style === "pixel" ? ".png" : ".jpg");
                    grabImage(root).save(path);   // returns nothing; check the files afterwards
                }
            }
        }
    }
}
