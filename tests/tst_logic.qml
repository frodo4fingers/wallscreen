import QtQuick
import QtTest
import "../package/contents/ui/logic.js" as Logic

TestCase {
    name: "Logic"

    readonly property var sunrise: new Date(2024, 5, 21, 6, 0, 0)
    readonly property var sunset: new Date(2024, 5, 21, 18, 0, 0)

    function el(h, m) {
        return Logic.celestial(new Date(2024, 5, 21, h, m || 0, 0), sunrise, sunset).elevation
    }

    function test_wmo() {
        var s = Logic.weatherState(0, 0, 0, 20000)
        compare(s.rain + s.snow + s.fog + s.storm, 0)
        verify(Logic.weatherState(63, 80, 0, 20000).rain > 0.3)
        verify(Logic.weatherState(73, 80, 0, 20000).snow > 0)
        verify(Logic.weatherState(95, 80, 0, 20000).storm > 0)
        verify(Logic.weatherState(45, 80, 0, 20000).fog > 0)
        verify(Logic.weatherState(2, 70, 0, 20000).clouds >= 0.7)
        verify(Logic.weatherState(0, 0, 0, 500).fog > 0.5)
        verify(Logic.presetWeather(5).storm > 0)
    }

    function test_elevation() {
        fuzzyCompare(el(12), 1, 0.01)
        fuzzyCompare(el(6), 0, 0.01)
        fuzzyCompare(el(18), 0, 0.01)
        verify(el(0) < 0)
        verify(el(3) < 0)
        verify(el(22) < 0)
    }

    function test_continuity() {
        verify(Math.abs(el(17, 59) - el(18, 1)) < 0.05)
        verify(Math.abs(el(5, 59) - el(6, 1)) < 0.05)
        verify(Math.abs(el(23, 59) - el(0, 1)) < 0.05)
    }

    function test_invalid_dates() {
        var c = Logic.celestial(new Date(NaN), new Date(NaN), new Date(NaN))
        verify(!isNaN(c.elevation))
    }

    function test_moon_phase() {
        fuzzyCompare(Logic.moonPhase(new Date("2000-01-21T04:40:00Z")), 0.5, 0.05)
    }

    function test_wind() {
        verify(Logic.windX(20, 270) > 0)
        verify(Logic.windX(20, 90) < 0)
    }
}
