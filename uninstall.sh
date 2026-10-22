#!/usr/bin/env bash
set -euo pipefail
id="voyagen.oma-orca-monitor"
config="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy"
omarchy plugin disable "$id" || true
rm -rf -- "$config/plugins/$id"
omarchy-shell shell rescanPlugins
omarchy restart shell
printf 'Removed Orca Monitor. Shell backups, if any, remain in %s.\n' "${XDG_STATE_HOME:-$HOME/.local/state}/oma-orca-monitor"
