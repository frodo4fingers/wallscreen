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
