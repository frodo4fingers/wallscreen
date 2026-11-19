# Wallscreen: weather + time live wallpaper (Plasma 6.6, Wayland)

Root: `/home/fd/projects/private/wallscreen/`. Package root: `package/`, plugin id `de.wallscreen.weather`.
Full plan: `/home/fd/.claude/plans/expressive-rolling-newt.md`.

## Interface contract (binding for all agents)

### Constants
- `HORIZON_Y = 0.62`: normalized screen y (0 = top, 1 = bottom) of the highest hill crest. The sky is visible above it.
- All coordinates are normalized 0-1, with screen y growing downward. Components multiply by `width`/`height`. Never use fixed pixel sizes. Scale strokes and particles from `Math.min(width, height)`.

### `package/contents/config/main.xml` (group `General`)
| Entry | Type | Default |
|---|---|---|
| City | String | Berlin |
| Latitude | Double | 52.52 |
| Longitude | Double | 13.405 |
| ResolvedCity | String | (empty) |
| CachedWeather | String | (empty) |
| PauseOnBattery | Bool | true |
| PauseWhenCovered | Bool | true |
| PreviewWeather | Int | 0 (0 Live, 1 Clear, 2 Cloudy, 3 Rain, 4 Snow, 5 Storm, 6 Fog) |
| PreviewHour | Int | -1 (-1 = live, otherwise 0-23) |

### `package/contents/ui/logic.js` (`.pragma library`, pure, no QML types)
- `weatherState(code, cloudCover, precip, visibility)` returns `{clouds, rain, snow, fog, storm}`, each 0-1. `code` is a WMO code. `cloudCover` is 0-100. `precip` is in mm/h. `visibility` is in m.
- `presetWeather(index)` returns the same shape as `weatherState` for `PreviewWeather` 1-6.
- `celestial(now, sunrise, sunset)` takes three Date objects and returns:
  - `elevation`: -1 at midnight, 0 at the horizon, 1 at solar noon. It is continuous.
  - `sunX`, `sunY`: normalized. The sun arcs from the left horizon to the right horizon. `sunY` is `HORIZON_Y` at sunrise and sunset, and about 0.12 at noon.
  - `moonX`, `moonY`: the same arc over the night.
  - `sunVisible`, `moonVisible`.
  - `starOpacity`: 0-1. It fades in after dusk.
- `skyColors(elevation, overcast)` returns `{top, bottom}` as `"#rrggbb"`. It interpolates continuously across night, dawn/dusk glow, and day. `overcast` (0-1) mixes the colors toward grey.
- `sceneLight(elevation, overcast)` returns 0-1, the landscape brightness multiplier. Night is about 0.15.
- `moonPhase(date)` returns 0-1, where 0 is new and 0.5 is full. It uses the synodic month 29.530588853 d from the new moon at 2000-01-06T18:14Z.
- `season(date, latitude)` returns an array of 4 `"#rrggbb"` hill colors, far to near. Spring, summer, autumn, and winter differ. The result is hemisphere-flipped when `latitude < 0`.
- `windX(speedKmh, dirDeg)` returns -1 to 1. Meteorological direction means wind FROM that direction, so 270 (from the west) pushes toward +x. It saturates at about 40 km/h.
- `HORIZON_Y` is exported as a var.

### Components (all in `package/contents/ui/`)
- `Weather.qml` (Item, no visuals)
  - In: `city` (string), `cfg` (the configuration map).
  - Out: `code`, `cloudCover`, `precipitation`, `windSpeed`, `windDir`, `visibility`, `temperature`, `sunrise` (Date), `sunset` (Date), `valid` (bool).
  - Method: `refresh()`.
- `Sky.qml`
  - In: `topColor`, `bottomColor`, `sunX`, `sunY`, `moonX`, `moonY`, `sunVisible`, `moonVisible`, `moonPhase`, `starOpacity`, `running`.
- `Clouds.qml`
  - In: `cover` (0-1), `darkness` (0-1), `windX` (-1 to 1), `tint` (color), `running`.
- `Landscape.qml`
  - In: `colors` (array of 4 color strings, far to near), `light` (0-1).
- `Precipitation.qml`
  - In: `rain` (0-1), `snow` (0-1), `windX` (-1 to 1), `running`.
- `main.qml` (`WallpaperItem`) wires everything, back to front:
  1. Sky
  2. Clouds
  3. Landscape
  4. Fog overlay
  5. Precipitation
  6. Lightning flash

## Rules for all agents
- Target Qt 6 and Plasma 6.6, QML/JS only. `qsb` is not installed, so no custom shaders and no `ShaderEffect` with `.frag`.
- Allowed imports: `QtQuick`, `QtQuick.Shapes`, `QtQuick.Particles`, `QtQuick.Effects`, `QtQuick.Controls`, `QtQuick.Layouts`, `org.kde.kirigami`, `org.kde.plasma.plasmoid`, `org.kde.plasma.core`, `org.kde.plasma.plasma5support`, `org.kde.taskmanager`.
- Reference wallpapers live in `/usr/share/plasma/wallpapers/` (`org.kde.color`, `org.kde.slideshow`). Config writes use `root.configuration.X = v; root.configuration.writeConfig()`.
- Do NOT run tests, `qmlscene`, `plasmashell`, or `kpackagetool6`. Do not edit files outside your assignment.
- No dataclasses, no extra files.

## Checklist
- [x] A (haiku): `metadata.json`, `config/main.xml`, `ui/config.qml`
- [x] B (sonnet): `ui/logic.js`, `tests/tst_logic.qml`
- [x] C (sonnet): `ui/Weather.qml`
- [x] D (sonnet): `ui/Sky.qml`, `ui/Clouds.qml`
- [x] E (sonnet): `ui/Landscape.qml`, `ui/Precipitation.qml`
- [x] Review wave 1 and run fix rounds (none needed)
- [x] F (sonnet): `ui/main.qml`
- [x] Review F (1 fix round: screen filter fallback, forced refresh, startup fade gate, cloud warm window)
- [x] G (haiku): `tests/tst_smoke.qml` smoke-load of scene components
- [ ] User installs and runs the verification steps from the plan
- [x] User runs tests (logic + smoke pass; Qt6 runner at /usr/lib/qt6/bin). qmllint: only unqualified-access style hints

## Review
- All 7 agent deliverables reviewed against contract. Wave 1 accepted first pass; F needed 1 round.
- Static only: no qmllint on system, tests not run by Claude (CLAUDE.md rule).
- Unverified at runtime: `Plasmoid.containment.screenGeometry` in wallpaper context, powermanagement "AC Adapter" key, lightning random gap re-read, ItemParticle rain perf (≤500 items).
- Known minor: wind sign flip mirrors cloud layer instantly (only on weather refresh).

---

# v2 Restyle: Japanese woodblock print (ukiyo-e style), vibrant colours

The user wants a woodblock print look with vibrant colours. Chosen motifs: a snow-capped volcano, umbrella pines, and a small pagoda or torii. No water. The style is generic ukiyo-e. Do NOT copy any specific existing print.

## Style rules (all agents)
- Flat colour fields. Every solid shape gets a dark ink outline: `INK = "#1d1a2e"`, width `Math.max(1.5, Math.min(width, height) * 0.0018)`, slightly rounded joins. Never draw outlines on the paper grain or the rain.
- Bokashi: a gradient wash, used as a band of strong colour that fades into a flat field (Rectangle gradients). Use bokashi on the sky top band, the sky horizon band, and the hill and mountain tops (the darker crest fades down).
- Vibrant palette:
  - Prussian blue: #1f4e9c / #3d7cc9
  - Indigo night: #141a3c
  - Vermilion: #e2462f
  - Sakura pink: #f08a8a
  - Cream sky and paper: #f3e7c4
  - Jade: #4fa36b
  - Emerald: #2f8a4e
  - Ochre: #d9a23b
  - Maple red: #c8432b
  - Snow white: #f7f4ec
- No blur and no MultiEffect. Flat look, which is also cheaper.
- Motion stays slow and subtle. All sizes are relative.

## v2 contract changes
- `logic.js`
  - `skyColors(elevation, overcast)` returns `{top, bottom, band, horizon, horizonAlpha}`:
    - `band`: the deep colour at the top of the sky. Prussian blue by day, near-black indigo by night.
    - `horizon`: the warm band just above the horizon. Vermilion or pink at dawn and dusk, pale yellow-cream at midday.
    - `horizonAlpha`: 0-1. Strongest at dawn and dusk, about 0.35 at day, 0 at deep night.
    - Overcast mutes all colours toward a soft blue-grey, but keeps some colour (vibrant even when grey).
  - `season(date, latitude)`: same shape (4 colours, far to near), with the vibrant woodblock palettes:
    - Spring: jade greens with a hint of sakura pink on the far layer.
    - Summer: emerald.
    - Autumn: ochre to maple red.
    - Winter: snow white with indigo shadows.
  - NEW `snowCap(date, latitude)` returns 0.15 to 0.55, the fraction of the volcano height covered in snow. It is largest in late winter and smallest in late summer, smooth over the year, and hemisphere-flipped.
  - NEW `var INK = "#1d1a2e"`.
- `Sky.qml`: new inputs `bandColor`, `horizonColor`, `horizonAlpha`. The other inputs are unchanged.
- `Clouds.qml`: the API is unchanged.
- `Landscape.qml`: new inputs `snowCap` (0-1) and `ink` (color). `colors` and `light` are unchanged.
- `Precipitation.qml`: the API is unchanged.
- NEW `Paper.qml`: input `strength` (0-1, default 0.5). It is a static washi paper grain overlay on top of everything.
- `main.qml`: wires the new props. The order is Sky, Clouds, Landscape, Fog, Precipitation, Lightning, Paper.

## v2 Checklist
- [x] B2 (sonnet): `logic.js` palettes plus `snowCap`, `INK`; update `tests/tst_logic.qml`
- [x] D2 (sonnet): `Sky.qml`, `Clouds.qml` restyle
- [x] E2 (sonnet): `Landscape.qml` restyle (volcano, pines, pagoda/torii)
- [x] P2 (sonnet): `Precipitation.qml` restyle plus new `Paper.qml`
- [x] Review wave (lint clean; offscreen render denied, visual check by user)
- [x] F2 (sonnet): `main.qml` wiring, update `tests/tst_smoke.qml`
- [ ] User visual check

## v3 "feel live" round
- [x] Runtime root cause: 3 maximized windows paused the wallpaper (by design). Bug: Show Desktop kept it paused. Fixed with `KWindowSystem.showingDesktop`.
- [x] Covered counter double-count fixed with `recount()`.
- [x] Clouds: pause warning fixed, 2-3x faster drift, parallax, bob. Stars twinkle.
- [x] Pines sway (Landscape). `id: layer` collision fixed (by me).
- [x] Life.qml: sakura/maple/fireflies plus ink bird flocks.
- [x] Lightning and flock moved to Timers (ScriptAction recursion crash fixed).
- [x] Installed, restarted, 40s log: no QML errors.
- [ ] User visual check (Meta+D)
- [ ] Remove diagnostic logging once the user confirms

---

# v4 Selectable styles
Goal: the current art becomes the "woodblock" style, and styles can be selected in the config. Git snapshot `woodblock-v1` (commit ceaaeef) was taken before the refactor.

## Layout
```
package/contents/ui/
  main.qml        shared: Weather, clock, smoothing, celestial, pause logic, preview. Loads the style via Loader.
  Weather.qml     shared
  logic.js        shared ONLY: weatherState, presetWeather, celestial, sceneLight, moonPhase, windX, HORIZON_Y
  styles.js       registry: var STYLES = [{ id: "woodblock", name: "Woodblock (ukiyo-e)" }]
  config.qml      + Style ComboBox (model from styles.js)
  styles/woodblock/
    Scene.qml     root of the style: composes the layers, owns its colours, fog, lightning, paper
    palette.js    skyColors, season, snowCap, INK (moved out of logic.js)
    Sky.qml Clouds.qml Landscape.qml Life.qml Precipitation.qml Paper.qml   (moved unchanged)
```

## Scene contract (every style's `Scene.qml`)
Root Item with exactly one input: `property var world`, a QtObject owned by main.qml with these notifying props:
- `now` (date), `latitude`, `month` (0-11, hemisphere-adjusted)
- `elevation`, `light` (`sceneLight`), `sunX`, `sunY`, `moonX`, `moonY`, `sunVisible`, `moonVisible`, `moonPhase`, `starOpacity`
- `clouds`, `rain`, `snow`, `fog`, `storm`, `windX` (already smoothed)
- `running` (pause flag), `instant` (true briefly after a preview change, so a style may skip its colour fades)

The style computes all its own colours from these values. It must handle `world` being null at load (use `world ? ... : default` or a guard).

## Config
- New entry `Style` (String, default "woodblock").
- An unknown id falls back to "woodblock" (in main.qml).

# v5 Second style: "Lofi Window" (designed and built by Opus directly, on request)
A cosy room window at the bottom of a tall city: the sky and skyline seen through a big
divided window, a cat on the sill watching the city, a pothos, books and a coffee mug,
a jar candle and fairy lights. Night is the signature look (indigo sky, warm windows,
lamp-lit plum room); day is pastel. Rain beads and runs down the glass.

## Files (`package/contents/ui/styles/lofi/`)
- `geometry.js`: pure JS, every shape as an SVG path in screen pixels (layout, city, clouds,
  branch, frost, ledge, plant, desk, candle, cat, garland). Seeded RNG, so the art is stable.
- `palette.js`: pure JS, `#rrggbb` keyframes by sun elevation, clear vs overcast (`sky`, `room`,
  `branch`, `lights`, `lamp`).
- `Scene.qml` (composition, shared 20-min clock, lamp glow, lightning), `Sky.qml`, `City.qml`,
  `Branch.qml`, `Rain.qml` (outside), `Glass.qml` (drops, mist, frost, snow ledge), `Room.qml`, `Cat.qml`.
- Sprites made with PIL: `drop.png`, `slide.png`, `streak.png`, `glow.png`, `flake.png`.

## Layout rules
- Window: side margin max(4.5% W, 7% H), top 6% H, sill at 80% H. Panes = round(width / (0.95 * height)),
  clamped 1..4, so 3 on 3440x1440, 2 on 1920x1080, 1 in portrait. Transom at 27% of the glass height.
- Object size unit u = 1% of min(H, 0.9 W). The cat sits in the middle lower pane (or right of centre).

## What moves
Clouds drift (whole cycles of one shared clock, so no jumps); stars twinkle; city windows switch on
and off; antenna beacons blink; a plane crosses now and then; the branch sways with the wind;
fairy lights shimmer; the candle flickers; steam rises from the mug; the cat breathes, swishes
its tail, twitches its ears and tilts its head. Rain: streaks outside, beads and running drops
with wet trails on the glass, blurred city behind wet glass. Snow: flakes, frost, a drift on the
ledge. Fog: haze layers and condensation. Storm: lightning that lights the room a little.

## Checklist
- [x] Geometry + palette, previewed as SVG at 21:9, 16:9 and portrait (day, dusk, night, rain, snow)
- [x] QML components, qmllint clean (except unqualified access and one dynamic itemAt property)
- [x] Installed; Plasma journal clean in every preview state (`./ws 1..6` at several hours)
- [x] Smoke + layout + palette tests added to `tests/tst_smoke.qml` (user runs them)
- [ ] User review of the look

## Review
- Runtime bugs found only through the journal, not qmllint: property names `L`/`H` (QML property
  names must start lowercase) and `top` on an Emitter (overrides the FINAL `Item.top` anchor line).
- The city uses the default Shape renderer (thousands of axis-aligned rects); curved art uses
  CurveRenderer for antialiasing.

# v6 Lofi: drops dry off, a cosier room
User feedback: raindrops stay on the glass after the rain stops; the room could be way more cosy
(look at lofi examples).

Lofi room recipe from the search: warm interior light against a cool, rainy window; a desk lamp;
plants everywhere; shelves of books; curtains; a steaming drink; small moving details.

## Plan
- [x] Drops: never stop the ParticleSystem (a stopped system freezes its particles); beads shrink and fade over ~25 s
- [x] Layout: desk across the bottom, a smaller centred window, wall on both sides (21:9, 16:9, 32:9, portrait)
- [x] Outside scaled to the window (`L.o`), sun and moon mapped into the window (`skyPoint`)
- [x] Curtains tied back, rod with rings, fairy lights draped along the rod
- [x] Desk: lamp with a light pool and cone (on from dusk / overcast), open notebook and pencil,
      mug with steam, radio with drifting notes, a cactus
- [x] Wall: shelves with books and a trailing pothos (left); a clock showing the real time and polaroids (right)
- [x] Hanging pothos in the window, swaying on the shared clock
- [x] Palette: one daytime colour per key, multiplied by the ambient light; lamp-lit keys warm up
- [x] Draw lists: geometry returns `{d, c, a, w}` ops; `Paint.qml` and the SVG preview draw the same list
- [x] Palette inputs quantised (elevation steps of 0.005), so 100+ shapes do not recolour every frame
- [x] Preview 21:9 / 16:9 / portrait / 32:9 at day, dusk, night and rain
- [x] Install, journal clean in all `ws` states; tests updated
- [ ] User runs the tests

## Review
- New furniture beyond the plan: radiator under the window, headphones on the desk, a snake plant
  (left end) and a jar of fairy lights on two books (right end), tiny lights on the photo string.
  Desk items that do not fit (narrow or portrait screens) are left out, never squeezed.
- New files: `Paint.qml` (generic draw-list painter), `Fairy.qml` (bulbs, used three times),
  `Curtains.qml`, `Hanger.qml`, `Desk.qml`, `note.png`. `Room.qml` rewritten; steam moved to `Desk.qml`.
- Sky clouds keep the continuous cloud value: it only drives opacities; a quantised value
  would make cloud fade-ins step (one step = 0.11 opacity). Everything that recolours shapes uses the quantised `tone`/`overcast`.
- `Pal.daylight` dropped with the daylight patch on the desk (hard edge, looked like a stain).
- qmllint: only unqualified-access style warnings left in the older `Sky.qml`/`Scene.qml`.
- Journal: no QML errors after install and through ws states 1-6 at several hours.

---

# v7 Lofi light on the GPU (screen flicker)
User report: the screen flickers from time to time. Measured with lofi visible on DP-1 (3440x1440 @100 Hz):
GPU 59-93 % busy (avg 71 %), plasmashell 36 % of GPU time, memory clock switching 800/1200 MHz twice a
second. The scene redrew ~170 shapes at display rate because several animations never stopped.
Display errors also predate the wallpaper (amdgpu DMCUB at boot/dock, KWin blur FB failure at 09:58).

## Plan
- [x] Scene clock from a 40 ms Timer (25 fps), integer ticks, exact 20 min wrap
- [x] Cat breath/swing and branch sway as clock functions (no infinite animations)
- [x] Plane flight driven by the clock instead of a vsync NumberAnimation
- [x] Steam and music notes as clock-driven items; Desk particle system and note.png removed
- [x] Glass and rain particle systems run only while wet and until empty
- [x] Rain moved out of the blurred outside layer
- [x] Static room, curtain fabric and desk cached in layers
- [x] main.qml sun/moon/elevation glides 60 s -> 2 s
- [x] main.qml glides and weather fades only while active (a covered screen redrew all the time)
- [x] Measure again (gpu_busy, plasmashell fdinfo share, fclk switches), dry and with ws 3 22
- [ ] User runs tests, watches for flicker

## Review
Covered screen: 0 fps, GPU 8 % busy, plasmashell 0 % (before: redrawing all the time, 79 % busy).
Visible, clear or cloudy: 29-35 fps, GPU 19-21 %, plasmashell 10-12 %.
Visible in rain: still 116 fps, GPU 64 %: Qt particle systems advance on every vsync and cannot be
throttled. Live weather was wet, so this was the common case. Follow-up in v8.

# v8 Rain, snow and glass drops without Qt particles
Rain and snow were the last display-rate load. No qsb on the system, so no shaders: static geometry,
regenerated rarely, moved and faded on the 25 Hz clock.

## Plan
- [x] Rain: 3 depth sheets of spindle streaks, 2 copies each, sliding along the wind slant
- [x] Snow: 6 sheets of flakes (3 depths x 2 sway phases), same scheme, sideways sway
- [x] Beads: 12 staggered groups of drop.png on 24 s cycles, rain level latched per cycle (glass dries)
- [x] Sliding drops: 10 per pane column on 16 s cycles, dotted trail revealed by a growing clip
- [x] Rain and Glass take the clock; particles, running, streak.png and flake.png removed
- [x] Smoke test for the new geometry at 5 screen sizes
- [x] Review diff and a preview still; qmllint; install; journal through ws states
- [x] Measure fps and GPU in rain, snow, storm, clear and live (target ~25-35 fps, ~20 %)
- [x] Blurred view captured on every fifth tick (the blur chain cost an extra frame per change)
- [x] Minute sun/moon glides removed (main.qml); window lights switch without a fade (City)
- [x] Cat twitch, flick and tilt and the lightning computed from the clock
- [x] Plane binding loop on t fixed; unused glow.png removed
- [ ] User runs tests, looks at ws 3 22 and ws 4 12, watches for flicker

## Review
Frames counted per window with QSG_RENDER_TIMING; GPU from gpu_busy_percent and DRM fdinfo, 6 s each,
3440x1440 at 100 Hz, wallpaper visible (PauseWhenCovered off for the test).

| state           | fps  | GPU busy | plasmashell |
|-----------------|------|----------|-------------|
| before v7       | ~100 | 71 %     | 36.5 %      |
| v7, rain        | 116  | 64 %     | 32 %        |
| v8, rain night  | 36   | 18 %     | 12 %        |
| v8, snow day    | 28   | 15 %     | 10 %        |
| v8, storm night | 36   | 19 %     | 14 %        |
| v8, fog morning | 33   | 17 %     | 11 %        |
| v8, clear noon  | 29   | 14 %     | 8 %         |
| v8, cloudy night| 27   | 13 %     | 9 %         |
| v8, live (wet)  | 35   | 17 %     | 11 %        |
| covered, paused | 0    | 8 %      | 0 %         |

Every state now draws one frame per 40 ms clock tick, plus a few for the 6 s sun/moon fades and the
30 s weather crossfades, which only run while the weather changes.

## Fix: wallpaper switch and missing desktop icons (2026-11-18)
- [x] Root cause: orphaned `[Containments][8]` (old `org.kde.plasma.private.systemtray`) claimed screen 0, so the config dialog and `setWallpaper` changed it instead of desktop containment 1
- [x] Backed up the config to `~/.config/plasma-org.kde.plasma.desktop-appletsrc.bak-2026-11-18-orphan-systray` and removed the group
- [x] Verified a `setWallpaper` round trip: Wallscreen loads, then is destroyed on switching back to image; `desktopForScreen(0)` is 1
- [x] Removed the `logPause()` and cover diagnostics (they wrote window titles to the journal)
- [ ] User switches with the wallpaper dialog both ways and confirms the icons stay after a re-login

# v10 Fourth style: "Sunlit Ocean (painting)"
The user's painting (open sea between cloud banks) with slow, quiet light. The user chose a
fixed sunny day and very subtle motion.
- [x] Assets made with PIL: `ocean.jpg`, `clouds.webp` (the painting cut out by a cloud mask),
  `rays.png`, `spark.png`, `shade.png`
- [x] `styles/ocean/Scene.qml`: cloud shadows drift over the sea under the static cloud
  cut-out; four glint groups fade in and out on the sun's path; the rays sway and breathe.
  The painting never moves. The clock ticks at 12.5 Hz.
- [x] Registered in `styles.js`; smoke tests `test_ocean_scene` and `test_ocean_scene_null_world`
- [x] Installed and live; GPU busy 16 % while animating against 9 % with the scene paused
- [x] User saw no motion: added four small clouds cut from the painting that drift over the sea with their shadows; glints and rays made stronger. GPU busy 11 %
- [x] User looks at it and runs the tests (all 18 passed)

# v11 Fifth style: "Pixel Loft"
Cozy modern loft in pixel art: a big window onto a large skyline, with the time of day and the
live weather outside. Weather comes from the existing Open-Meteo source (15 min poll).
- [x] `tools/pixel_loft.py` draws the room (day and night lighting), the sleeping and walking cat, and writes `art.js`
- [x] `styles/pixel/draw.js`: sky bands, sun, moon phase, stars, clouds, skyline with lit windows, fog, rain, snow, and the cat's schedule
- [x] `tools/pixel_preview.js` renders the window with the real draw.js for still previews
- [x] `styles/pixel/Scene.qml`: 576x240 art in one layer, scaled by a whole number with nearest-neighbour sampling; 12.5 Hz clock
- [x] Cat walks along the bench about every 10 min (user request)
- [x] Desk and PC replaced by a three-tier plant shelf with the mug and a mushroom lamp (user request)
- [x] Registered in `styles.js`; smoke tests `test_pixel_scene` and `test_pixel_scene_null_world`
- [x] Installed and live; GPU busy 12 % (clear and rainy night preview)
- [ ] User looks at it and runs the tests
