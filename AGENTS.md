# Working on Wallscreen

Notes for anyone changing this repository, whether a person or a coding agent. The README
covers installation and what a style's `Scene.qml` receives ("Writing a style"). This file has
the rules that keep the wallpaper cheap to run and calm to look at, and the checks to run
before committing.

## Performance rules

A wallpaper runs all day, so a few percent of CPU or GPU adds up. Qt Quick renders a new frame
whenever anything animates, and any running `Animation` or `ParticleSystem` makes it render on
every vsync, which is 100 to 144 times a second on many screens. Each style therefore drives all
its motion from one slow clock.

- Each style has one `Timer` clock in its `Scene.qml`: 40 ms (25 Hz) for Woodblock and Lofi
  Window, 80 ms (12.5 Hz) for Sunlit Ocean and Pixel Loft. Copy that pattern for a new style.
  The timer runs only while `world.running` is true, so a paused wallpaper draws nothing.
- Motion is a pure function of the clock. Woodblock and Lofi use `ticks` from 0 to 29999 and
  `clock = ticks / 30000`, one cycle every 20 minutes. Anything periodic repeats a whole number
  of times per cycle, so the wrap at the end of the cycle does not jump.
- No infinite or long-running `NumberAnimation`, `SequentialAnimation` or `ColorAnimation`, and
  no Qt particle systems; they cannot be throttled. Rain and snow are sheets of static geometry
  that slide on the clock (`styles/lofi/Rain.qml`, `styles/woodblock/precip.js`).
- Use a `Behavior` only for a short fade on a rare change, such as the weather or the season,
  never on a value that changes every minute, such as the sun's elevation.
- Colours step instead of fading. Round their inputs before computing colours, for example
  `Math.round(elevation * 200) / 200`, so hundreds of shapes recolour once every minute or two
  and not on every tick.
- Gate the clock for items that are not visible
  (`readonly property real c: visible ? root.clock : 0`), so their bindings do not re-evaluate.
- Canvases repaint only when what they show has changed, not on every tick.
- Rebuild path geometry only when the size or a quantised input changes. Moving, rotating and
  fading an item is cheap; changing its `PathSvg` every tick is not.

Measure a change with `tools/bench.sh` on the live desktop before and after. As a guide, a
style should stay near the numbers in the README's resource table: about 10 % of one core
for plasmashell and about 20 % GPU busy at 3440x1440 and 100 Hz.

## Look and motion

- Keep motion slow and quiet: no fast blinking or strobing. Lightning stays short and rare.
- Use seeded randomness (a hash of an index) in bindings, never `Math.random()`, so the picture
  is stable and the same on every redraw. `Math.random()` is fine inside a one-off function such
  as scheduling the next flock of birds.
- `world` is null while a scene loads. Read every value with a default (`world?.rain ?? 0`).
- Do not name a property after one that `Item` already has, such as `left`, `top`, `state` or
  `data`. QML refuses to load the file, and `qmllint` does not always warn about it.

## Checking a change

Before committing:

1. Run `qmllint` on the QML files you changed: `/usr/lib/qt6/bin/qmllint <file>`.
2. Run the tests:
   ```sh
   for t in tst_logic tst_woodblock tst_smoke; do
       QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/$t.qml
   done
   ```
   A new style needs a creation test in `tests/tst_smoke.qml`, including one with `world` null.
3. Render the stills and look at them:
   `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tools/screenshots.qml`.
   The offscreen renderer has no shaders, so shader effects such as blur are missing there.
4. Install and look at it live: `kpackagetool6 -t Plasma/Wallpaper -u package`, then
   `systemctl --user restart plasma-plasmashell`. Plasma caches QML, so the restart is needed.
   Check `journalctl --user -b` for QML warnings, and step through the weather with `./ws`.
5. Run `tools/bench.sh <style>` if the change touches motion or drawing.

Restarting Plasma flashes the whole desktop. Batch changes and restart once, not after every
edit.

## Generated art

The Pixel Loft room and cat sprites come from `tools/pixel_loft.py` (Pillow and NumPy). Change
the generator and run it rather than editing the PNGs by hand:
`python3 tools/pixel_loft.py`. It writes the images and `art.js` into `styles/pixel/`.

## Commits

Conventional Commits (`feat(pixel): ...`, `perf(woodblock): ...`, `docs: ...`), with the
reason for a change in the body when it is not obvious from the subject.
