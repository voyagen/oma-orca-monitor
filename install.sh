#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
id="voyagen.oma-orca-monitor"
config="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy"
dest="$config/plugins/$id"
state="${XDG_STATE_HOME:-$HOME/.local/state}/oma-orca-monitor"
omarchy plugin validate .
python3 -B -m unittest -q
mkdir -p "$state"
if [[ -f "$config/shell.json" ]]; then
    backup="$state/shell.json.$(date +%Y%m%d-%H%M%S-%N).bak"
    cp -p -- "$config/shell.json" "$backup"
    printf 'Shell configuration backup: %s\n' "$backup"
fi
mkdir -p "$dest"/{i18n,icons,fonts,licenses}
install -m 644 manifest.json qmldir BarWidget.qml MonitorContent.qml PlainText.qml AgentIcon.qml StatusIndicator.qml ThemedIcon.qml BarStatus.qml Service.qml Backend.qml monitor.py orca.svg pending.svg LICENSE README.md "$dest/"
install -m 644 i18n/en.json "$dest/i18n/"
install -m 644 icons/* "$dest/icons/"
install -m 644 fonts/* "$dest/fonts/"
install -m 644 licenses/* "$dest/licenses/"
omarchy plugin validate "$dest"
omarchy-shell shell rescanPlugins
# Discovery is asynchronous after the rescan request.
for attempt in {1..30}; do
    if omarchy plugin list --json | python3 -c 'import json,sys; sys.exit(not any(p["id"] == "voyagen.oma-orca-monitor" for p in json.load(sys.stdin)))'; then
        break
    fi
    sleep 0.2
done
omarchy plugin enable "$id" --section right --index 0
# Quickshell can retain QML components outside its root across a rescan.
omarchy restart shell
printf 'Installed Orca Monitor beside your existing widgets.\n'
