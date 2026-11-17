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

    function test_season_hemispheres() {
        var july = new Date(2024, 6, 15)
        verify(Logic.season(july, 50).join() !== Logic.season(july, -50).join())
        compare(Logic.season(july, 50).length, 4)
    }

    function test_wind() {
        verify(Logic.windX(20, 270) > 0)
        verify(Logic.windX(20, 90) < 0)
    }

    function test_sky_colors() {
        var re = /^#[0-9a-f]{6}$/
        for (var e = -1; e <= 1; e += 0.25) {
            for (var o = 0; o <= 1; o += 0.5) {
                var c = Logic.skyColors(e, o)
                verify(re.test(c.top), c.top)
                verify(re.test(c.bottom), c.bottom)
                verify(re.test(c.band), c.band)
                verify(re.test(c.horizon), c.horizon)
                verify(c.horizonAlpha >= 0 && c.horizonAlpha <= 1)
            }
        }
    }

    function test_horizon_alpha() {
        var a0 = Logic.skyColors(0, 0).horizonAlpha
        verify(a0 > Logic.skyColors(1, 0).horizonAlpha)
        verify(a0 > Logic.skyColors(-1, 0).horizonAlpha)
        verify(Logic.skyColors(0, 1).horizonAlpha < a0)
    }

    function test_snow_cap() {
        var feb = new Date(2024, 1, 15), aug = new Date(2024, 7, 15)
        verify(Logic.snowCap(feb, 50) > Logic.snowCap(aug, 50))
        verify(Logic.snowCap(feb, -50) < Logic.snowCap(aug, -50))
        for (var m = 0; m < 12; m++) {
            var c = Logic.snowCap(new Date(2024, m, 10), 50)
            verify(c >= 0.15 && c <= 0.55, String(c))
        }
    }

    function test_ink() {
        compare(Logic.INK, "#1d1a2e")
    }
}
