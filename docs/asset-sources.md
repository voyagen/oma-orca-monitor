# Sidebar asset sources

Orca source: https://github.com/stablyai/orca, revision `acc235187f626ca2af6d0fb17f8ec8ec3ae6b227` (read on 2026-10-18).

- Agent SVG geometry comes from `src/renderer/src/lib/agent-icon-glyphs.tsx` and `src/renderer/src/components/status-bar/icons.tsx`. JSX attributes were converted to SVG attributes. Monochrome `currentColor` geometry is stored as a white alpha mask and tinted at runtime to the Omarchy foreground; brand colors are retained. Omp's OKLCH gradient stops are converted to sRGB for Qt SVG.
- Provider PNGs come from `src/shared/agent-icons/`; OpenClaude uses `resources/openclaude-logo.png`, as its sidebar catalog does. No runtime favicon service is used. Unknown providers get the same initial-letter fallback rather than an invented logo.
- Folder, refresh, check-circle, dashed-circle and question-bubble SVGs come from https://github.com/lucide-icons/lucide/tree/main/icons. These are the Lucide icons imported by Orca.
- The working ring ports `AgentWorkingSpinner.tsx` and `assets/main.css`: 8px workspace / 6px agent diameter, 2px border, 12 rotation steps per second, one revolution per second. Reduced motion uses a complete static ring. All status and interface SVGs are white alpha masks tinted live with Omarchy's accent, urgent or muted ink. These are status indicators, not percent-complete graphics.
- Geist is bundled from https://github.com/vercel/geist-font (`fonts/Geist/variable/Geist[wght].ttf`). This is the font family used by Orca's sidebar. It is loaded locally, not installed system-wide.
- Card title, primary badge and agent row sizing follow `worktree-card-header.tsx`, `worktree-card-compact-agent-row.tsx`, `StatusIndicator.tsx`, and `AgentStateDot.tsx`: 13px titles, 11px compact agent text, 10px timestamps, 16px primary badges and 24px agent rows.

Required license texts are bundled in `licenses/`. Provider logos remain their respective owners' marks. This plugin is not affiliated with Orca or the providers.

Deliberate differences: the popup retains Omarchy's positioning, keyboard handling and outer border; all sessions remain expanded, with whole-workspace interaction. Orca's settings, notification and creation controls are not copied as nonfunctional buttons. Completion, attention and interrupted states retain their distinct meanings.
