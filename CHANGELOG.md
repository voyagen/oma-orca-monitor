# Changelog

## 0.1.0

First release.

- Bar widget with Orca logo and aggregate status (working, ready, needs attention, interrupted, unknown, stale).
- Popup grouped by project and workspace, with always-visible agent rows sorted by recent activity.
- Click or keyboard navigation to the matching live Orca terminal.
- Follows the active Omarchy theme live; bundled provider logos, Lucide icons and Geist font.
- Configurable refresh interval (`refreshIntervalSec`).
- Shared polling service with backoff; stale data is marked, never presented as current.
