#!/bin/bash
# Measure what each style costs while it animates on the live desktop.
# Usage: tools/bench.sh [style ...]     (default: every style)
#
# For each style: switch to it, let it settle for 35 s, then average over 20 s the GPU busy
# percentage, the CPU time of plasmashell and kwin_wayland (as a share of one core), and
# plasmashell's resident memory. "Pause when covered" is turned off for the run, so a maximized
# window does not stop the animation; the style and that setting are restored on exit.
# Needs an amdgpu card (gpu_busy_percent in sysfs). The wallpaper visibly switches styles.
set -u
styles=("$@")
[ ${#styles[@]} -gt 0 ] || styles=(woodblock lofi ocean forest pixel)

qdbus=/usr/lib/qt6/bin/qdbus
select="desktops().filter(d => d.screen >= 0 && d.wallpaperPlugin == 'de.wallscreen.weather')"
group="d.currentConfigGroup = ['Wallpaper', 'de.wallscreen.weather', 'General'];"
ws() {   # ws Key value [Key value ...]: write wallpaper settings on every Wallscreen screen
    local js="$select.forEach(d => { $group"
    while [ $# -ge 2 ]; do js+=" d.writeConfig('$1', $2);"; shift 2; done
    js+=" d.reloadConfig(); })"
    $qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$js" >/dev/null
}
current=$($qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
    "$select.slice(0, 1).forEach(d => { $group print(d.readConfig('Style')); })")
[ -n "$current" ] || { echo "no screen uses the Wallscreen wallpaper" >&2; exit 1; }
trap "ws PauseWhenCovered true Style \"'$current'\"" EXIT

pause() { timeout "$1" tail -f /dev/null; }
gpu=$(ls /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1)
[ -n "$gpu" ] || { echo "no gpu_busy_percent found (amdgpu only)" >&2; exit 1; }
ps_pid=$(pgrep -x plasmashell); kw_pid=$(pgrep -x kwin_wayland)
tck=$(getconf CLK_TCK)
cpu() { awk '{print $14 + $15}' "/proc/$1/stat"; }

measure() {   # measure label: 40 samples, 0.5 s apart
    local a0 b0 a1 b1 s=0 n=40
    a0=$(cpu "$ps_pid"); b0=$(cpu "$kw_pid")
    for _ in $(seq $n); do s=$((s + $(cat "$gpu"))); pause 0.5; done
    a1=$(cpu "$ps_pid"); b1=$(cpu "$kw_pid")
    local rss
    rss=$(awk '/VmRSS/ {print int($2 / 1024)}' "/proc/$ps_pid/status")
    awk -v l="$1" -v g=$((s / n)) -v pa=$((a1 - a0)) -v kb=$((b1 - b0)) -v t="$tck" -v r="$rss" \
        'BEGIN { printf "%-10s gpu %3d%%  plasmashell %5.1f%%  kwin %5.1f%%  rss %d MiB\n", l, g, 100*pa/t/20, 100*kb/t/20, r }'
}

ws PauseWhenCovered false
for s in "${styles[@]}"; do
    ws Style "'$s'"
    pause 35
    measure "$s"
done
