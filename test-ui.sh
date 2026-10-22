#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
root=$(mktemp -d)
trap 'rm -rf -- "$root"' EXIT
# Mirror shell module imports without loading or modifying the live shell.
ln -s /usr/share/omarchy/shell/Commons "$root/Commons"
ln -s /usr/share/omarchy/shell/Services "$root/Services"
cp UiTest.qml MonitorContent.qml PlainText.qml AgentIcon.qml StatusIndicator.qml ThemedIcon.qml BarStatus.qml pending.svg "$root/"
cp -r i18n icons fonts "$root/"
timeout 15 quickshell -p "$root/UiTest.qml" 2>&1 | tee "$root/output"
grep -q 'UI_PASS:' "$root/output"
! grep -q 'UI_FAIL:' "$root/output"
