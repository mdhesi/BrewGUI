# BrewGUI

Native macOS GUI for Homebrew. SwiftUI (macOS 26 Tahoe), talks to `brew` via
`Process`/`Pipe`. Goal: a polished, production-quality Mac app with an Apple
**Liquid Glass** aesthetic — feel like the App Store's *Installed* tab or
Transmit, not a list of rows with buttons.

## Architecture
Layered, not monolithic. Groups under `BrewGUI/`:
- `Services/` — `BrewProcess` (async `run` + streaming `stream`, brew-path
  discovery), `BrewAPIClient` (Homebrew JSON API), `APICache` (disk cache).
- `Models/` — `Codable` API models + domain models (`PackageSummary`,
  `PackageDetail`, analytics, etc.).
- `ViewModels/` — `@MainActor @Observable` view models, one per screen, plus the
  shared `OperationCenter` for streamed install/uninstall/upgrade.
- `Views/` — one SwiftUI view per screen + shared components.
- `DesignSystem/` — `Spacing` (8pt grid), `Theme`, glass/material helpers.

The project uses **file-system-synchronized groups** — new files under
`BrewGUI/` are auto-added to the target; no `project.pbxproj` edits needed.

## Design rules
- Follow native macOS HIG; adopt **Liquid Glass** (macOS 26): `.glassEffect()` /
  `GlassEffectContainer` for floating toolbars, search, and action controls;
  `.glass` / `.glassProminent` button styles; `.regularMaterial` /
  `.thinMaterial` for sidebars and panels.
- `NavigationSplitView`: sidebar (Browse, Installed, Outdated, History, Services,
  Cleanup, Health) → content → detail.
- SF Symbols throughout; **8pt spacing grid** via `Spacing`; large prominent
  search; smooth **spring** animations on install/remove.
- Destructive actions (Remove) are **hover-reveal or context-menu only** — never
  a persistent button on every row.
- List rows are **two-line**: name primary, version/metadata secondary grey.
- Window chrome (Refresh, Search) lives in the **toolbar**, not inline.
- Test **light AND dark mode** for every UI change.

## Code rules
- **No force-unwraps** in UI code.
- All brew calls are **async** (`BrewProcess`), with **loading and error states
  surfaced in the UI** — never silent failures. Long operations stream live
  output through `OperationCenter`.
- API data comes from the **Homebrew JSON API** (`formulae.brew.sh/api/`):
  metadata, sizes, and 30/90/365-day install analytics. Cache responses locally;
  refresh on launch + manual pull; serve stale cache offline.
- brew discovery must handle both `/opt/homebrew` (Apple Silicon) and
  `/usr/local` (Intel).
- Accessibility labels on all controls.

## Workflow
- Work **one screen at a time**.
- After each change, **stop and ask me to screenshot** the running app (light
  AND dark) and paste it back before continuing.
- **Commit after each working screen.**

## Work order (roadmap)
0. ✅ Foundation: async/streaming `BrewProcess`, `BrewAPIClient` + `APICache`,
   `@Observable` view models + `OperationCenter`, design system, navigation
   shell, first-launch gate.
1. Installed — redesigned rows, glass toolbar, searchable + result count.
2. Outdated — per-row + bulk "Upgrade All" with live log.
3. Browse + Popular — search all formulae/casks, analytics-ranked popularity.
4. Package detail pane — desc, homepage, version, license, deps, install count,
   download + installed-on-disk size.
5. Operation center — streamed install/uninstall/upgrade log + progress.
6. Services — start/stop/restart brew services.
7. Cleanup — reclaimable disk space via brew cleanup.
8. Health — brew doctor surfaced cleanly.
9. History — recently removed + reinstall (own sidebar item).
10. Liquid Glass polish pass — blending, animations, light/dark parity.
