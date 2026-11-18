# Lessons

### Orchestrate, don't implement
- **What**: User rejected plan exit; wants me as orchestrator + reviewer, delegating implementation to sonnet/haiku agents on high effort, with re-rounds when work is unsatisfying.
- **Why**: User preference for multi-agent build with me reviewing.
- **Rule**: For implementation work, split into disjoint-file tasks, spawn sonnet/haiku agents with `effort: high`, review output against the contract, send fix rounds via SendMessage.

### Reload Plasma via systemd, not `plasmashell --replace &`
- **What**: I told the user to run `plasmashell --replace &`. That left plasmashell as a child of their terminal, with the systemd service dead.
- **Why**: Closing the terminal would kill the desktop. Repeated runs also make it unclear how many instances are running.
- **Rule**: To reload after `kpackagetool6 -u`, use `systemctl --user restart plasma-plasmashell`.

### Never mutate animation durations from a ScriptAction inside the running group
- **What**: I specified lightning and flock gaps as a `ScriptAction` setting `PauseAnimation.duration` inside a looping SequentialAnimation. At runtime this caused a binding loop and `RangeError: Maximum call stack size exceeded`.
- **Why**: Qt recomputes the group duration while it is running, which recurses.
- **Rule**: Schedule random gaps with a non-repeating `Timer` (set `interval`, then `restart()`), and keep animations themselves static. Pause animations with `paused: running && !root.running`.

### Never use `layer` as a QML id
- **What**: `id: layer` on a Shape was shadowed inside child Items by the built-in `Item.layer` grouped property, so the trees silently got no model.
- **Rule**: Avoid ids that collide with Item properties (`layer`, `state`, `data`, `children`, `parent`). Run qmllint after every agent round.

### qmllint misses some fatal property errors; always read the journal after install
- **What**: The lofi style used property names `L` and `H` and an Emitter property `top`. qmllint passed, and Plasma then failed with "Property names cannot begin with an upper case letter" and "Cannot override FINAL property".
- **Why**: QML property names must start lowercase. `top`, `left`, `right`, `bottom`, `horizontalCenter`, `verticalCenter` and `baseline` are FINAL anchor lines on every Item.
- **Rule**: Use lowercase property names only, and never reuse Item property names. After every install, restart through systemd and grep the journal before reporting success.

### Never stop a ParticleSystem to save work when its emitters go quiet
- **What**: The lofi glass and outside rain bound `ParticleSystem.running` to `rain > 0.01`. When the rain ended, the system stopped with its drops still on screen, so they stayed on the window forever (user report).
- **Why**: A stopped ParticleSystem freezes its live particles in place. It does not clear them or let them age out.
- **Rule**: Gate emission with `Emitter.enabled` and pause with `paused: !running` only. Leave `ParticleSystem.running` at its default, so particles finish their lifespans. (Superseded for the lofi style: it no longer uses particles at all, see "Qt particles tick per vsync".)

### A wallpaper must never animate at display rate
- **What**: The lofi style redrew ~170 shapes at 100 fps. The causes were a NumberAnimation clock, infinite sway animations, always-on particles, and 60 s sun/moon glides restarted every minute. The GPU was 71 % busy while the user saw flicker. The never-ending glides even kept a covered, "paused" screen redrawing.
- **Why**: Any running Animation, Behavior or ParticleSystem makes the Qt Quick window render on every vsync, and KWin then recomposites the whole output.
- **Rule**: Drive all motion from one Timer-ticked clock (25 Hz). Use no infinite animations. Use Behaviors only for short transitions, and only while the wallpaper is active. Before calling a change done, check the frames per window with QSG_RENDER_TIMING (`systemctl --user set-environment`, restart plasmashell, count "frame rendered"), not only gpu_busy.

### Qt particles tick per vsync and cannot be throttled
- **What**: With everything else on the 25 Hz clock, rain still drew at 116 fps and 64 % GPU, through the glass and rain particle systems.
- **Why**: ParticleSystem time comes from Qt's animation driver, which advances on every vsync. There is no step or rate API, and `paused` only freezes time.
- **Rule**: Do not use QtQuick.Particles in a wallpaper. Use static geometry that is regenerated rarely and moved or faded on the clock, such as sliding sheets or groups latched per cycle.

### Caveman ultra holds through compaction and long reports
- **What**: After a context compaction, the session hook announced caveman "full". My status lines and plan summaries then drifted into normal prose, and the user re-sent `/caveman ultra`.
- **Why**: The user set ultra explicitly. A hook default, a compaction, or a long technical report does not change the level.
- **Rule**: Keep the last level the user set (ultra), whatever a hook announces. Check every reply against it before sending, including status lines, plan summaries and agent hand-off reports.
- **Repeat (second compaction)**: The user re-sent `/caveman ultra` right after another compaction whose hook again announced "full". The first reply after any compaction must already be ultra, before the user has to restate it.

### A blurred layer renders an extra frame after every change
- **What**: The lofi outside view had `layer.enabled` with a MultiEffect blur. Its content changed on every clock tick, and each change cost a second frame (intervals of about 6 ms and 34 ms instead of 40 ms), so wet and foggy states ran at 60-70 fps.
- **Why**: The blur's chained texture sources update one frame after the source changes.
- **Rule**: Never feed a live, changing subtree into a blur. Capture it with a non-live ShaderEffectSource and `scheduleUpdate()` at a low rate (here every fifth tick). Keep fast parts such as rain and lightning outside the captured view.

### Test wallpaper switching through PlasmaShell.setWallpaper, not the scripting API
- **What**: The user could not switch from Wallscreen back to the image wallpaper, and desktop icons were missing. I first tested switches with `evaluateScript` and `d.wallpaperPlugin = ...`. Nothing changed on screen, even between stock plugins, and the tests were misleading.
- **Why**: The scripting wrapper only applies `wallpaperPlugin` in its destructor, which runs at some later GC time. The config dialog's Apply calls `ShellCorona::setWallpaper()`, the same path as the D-Bus method `org.kde.PlasmaShell.setWallpaper`. The real cause was an orphaned `[Containments][8]` (old `org.kde.plasma.private.systemtray`, a plugin Plasma 6.6 no longer ships) with `lastScreen=0`. `Corona::containmentForScreen()` returns the last match, so every screen-0 lookup hit containment 8 instead of the desktop. Removing the group fixed it.
- **Rule**: Reproduce wallpaper switches with `gdbus call ... org.kde.PlasmaShell.setWallpaper <plugin> '{}' 0` and check `desktopForScreen(0).id`. When a desktop setting "does not apply", look for stale containments in plasma-org.kde.plasma.desktop-appletsrc before suspecting our package. Never truncate a containment listing with `head`.

### Keep the screen calm while the user is looking
- **What**: While measuring the Lagoon style, I restarted plasmashell about six times in a row and showed a vivid, busy scene. The user said "my eyes hurt looking at this" and stopped the style.
- **Why**: Every restart flashes the desktop, and the scene itself was loud. The user sits in front of this screen all day.
- **Rule**: Batch performance runs and say before restarting Plasma repeatedly. Default to subtle, slow motion and calm colours for wallpaper work. Check a design with the user through stills (preview PNGs) before putting it live on their desktop.

### Assert every scripted text replacement
- **What**: A Python `str.replace` on Scene.qml matched nothing and failed silently. The drift arrays kept 4 fields, the sprite source read `[4]` as undefined, and three Plasma restarts went by before the cause was found.
- **Why**: `replace` returns the text unchanged when the old text is absent, so a stale or mistyped search string goes unnoticed.
- **Rule**: In scripted edits, `assert old in s` before each replace (or use the Edit tool, which fails loudly). Before restarting Plasma to test, grep the file for the new text.
