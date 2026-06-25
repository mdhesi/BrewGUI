# BrewGUI

Native macOS GUI for Homebrew. SwiftUI, talks to `brew` via `Process`/`Pipe`.
Goal: feel like a native Mac app — App Store's *Installed* tab or Transmit — not a list of rows with buttons.

## Design rules
- Follow native macOS HIG.
- Destructive actions (Remove) are **hover-reveal or context-menu only** — never a persistent button on every row.
- List rows are **two-line**: name in primary text, version/metadata in secondary grey.
- Window chrome (Refresh, Search) lives in the **toolbar**, not inline.
- Test **light AND dark mode** for every UI change.

## Code rules
- **No force-unwraps** in UI code.
- All brew calls are **async** with **loading and error states surfaced in the UI** — never silent failures.
- brew discovery must handle both `/opt/homebrew` (Apple Silicon) and `/usr/local` (Intel).
- Accessibility labels on all controls.

## Workflow
- Work **one screen at a time**.
- After each change, **stop and ask me to screenshot** the running app and paste it back before continuing.
- **Commit after each working screen.**

## Work order
1. Redesign the package list row — two-line layout, hover-reveal Remove, calm at rest.
2. Move Refresh into the toolbar; add a `.searchable` field that filters live with a result count.
3. Per-package loading state during install/remove; surface brew errors as inline alerts.
4. Empty states + a first-launch view for when `brew` isn't on PATH.
5. Package detail view matching the row's visual language.
