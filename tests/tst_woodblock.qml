import QtQuick
import QtTest
import "../package/contents/ui/styles/woodblock/palette.js" as Palette

TestCase {
    name: "Woodblock"

    function test_season_hemispheres() {
        var july = new Date(2024, 6, 15)
        verify(Palette.season(july, 50).join() !== Palette.season(july, -50).join())
        compare(Palette.season(july, 50).length, 4)
    }

    function test_sky_colors() {
        var re = /^#[0-9a-f]{6}$/
        for (var e = -1; e <= 1; e += 0.25) {
            for (var o = 0; o <= 1; o += 0.5) {
                var c = Palette.skyColors(e, o)
                verify(re.test(c.top), c.top)
                verify(re.test(c.bottom), c.bottom)
                verify(re.test(c.band), c.band)
                verify(re.test(c.horizon), c.horizon)
                verify(c.horizonAlpha >= 0 && c.horizonAlpha <= 1)
            }
        }
    }

    function test_horizon_alpha() {
        var a0 = Palette.skyColors(0, 0).horizonAlpha
        verify(a0 > Palette.skyColors(1, 0).horizonAlpha)
        verify(a0 > Palette.skyColors(-1, 0).horizonAlpha)
        verify(Palette.skyColors(0, 1).horizonAlpha < a0)
    }

    function test_snow_cap() {
        var feb = new Date(2024, 1, 15), aug = new Date(2024, 7, 15)
        verify(Palette.snowCap(feb, 50) > Palette.snowCap(aug, 50))
        verify(Palette.snowCap(feb, -50) < Palette.snowCap(aug, -50))
        for (var m = 0; m < 12; m++) {
            var c = Palette.snowCap(new Date(2024, m, 10), 50)
            verify(c >= 0.15 && c <= 0.55, String(c))
        }
    }

    function test_ink() {
        compare(Palette.INK, "#1d1a2e")
    }
}
