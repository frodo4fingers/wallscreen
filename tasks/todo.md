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
