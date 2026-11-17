#!/usr/bin/env bash
# Preview Wallscreen states on all screens.
# Usage: ./ws <weather> [hour]
#   weather: 0 live, 1 clear, 2 cloudy, 3 rain, 4 snow, 5 storm, 6 fog
#   hour:    0-23, or -1 / omitted for live time
set -euo pipefail

weather=${1:?usage: ws <weather 0-6> [hour 0-23|-1]}
hour=${2:--1}
[[ $weather =~ ^[0-6]$ ]] || { echo "weather must be 0-6" >&2; exit 1; }
[[ $hour =~ ^(-1|[0-9]|1[0-9]|2[0-3])$ ]] || { echo "hour must be 0-23 or -1" >&2; exit 1; }

/usr/lib/qt6/bin/qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
desktops().filter(d => d.screen >= 0 && d.wallpaperPlugin == 'de.wallscreen.weather').forEach(d => {
  d.currentConfigGroup = ['Wallpaper', 'de.wallscreen.weather', 'General'];
  d.writeConfig('PreviewWeather', $weather);
  d.writeConfig('PreviewHour', $hour);
  d.reloadConfig();
})"
