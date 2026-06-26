<div align="center">

# 🍺 BrewGUI

**A native Mac home for Homebrew.**

See everything `brew` installed, spot what's outdated, browse the whole catalog,
and install or update it all — without opening a terminal.

[Website](https://mdhesi.github.io/BrewGUI/) · [Architecture](ARCHITECTURE.md) · [Releasing](RELEASING.md)

![BrewGUI](docs/screenshot.png)

</div>

---

## What it is

BrewGUI is a native macOS app (SwiftUI, macOS 14+) that puts a polished window in
front of the `brew` command-line tool. Every action maps to a real brew command —
nothing happens to your machine that you couldn't run yourself — but you get a
fast, native, Liquid-Glass interface instead of a terminal.

It reads two sources: your **local Homebrew state** (via the `brew` binary) and the
public **Homebrew JSON API** (`formulae.brew.sh`) for descriptions, icons, and
install analytics.

## Features

- **Browse** — search the full catalog (~16k formulae + casks), with real package
  icons, a detail pane (description, source link, version, license, dependencies,
  install counts), and one-click install. Paginated and cached so it stays fast.
- **Installed** — everything `brew` installed, two-line rows, hover-to-remove.
- **Outdated** — per-package and bulk "Upgrade All", with live streamed output.
- **History** — recently removed packages, with one-click reinstall.
- **Live operation log** — install/upgrade/uninstall stream their output in real
  time, including a **Trust & Retry** flow for casks from untrusted third-party taps.
- **Native through and through** — Homebrew-amber accent, SF Symbols, light + dark.

## Install

> A signed release is in progress. For now, build from source (below).

Once released:

```sh
brew install --cask mdhesi/tap/brewgui
```

…or grab the `.dmg` from [Releases](https://github.com/mdhesi/BrewGUI/releases).

## Build from source

Requires Xcode 16+ and macOS 14 (Sonoma) or later.

```sh
git clone https://github.com/mdhesi/BrewGUI.git
cd BrewGUI
open BrewGUI.xcodeproj      # then ⌘R
```

Or from the command line:

```sh
xcodebuild -project BrewGUI.xcodeproj -scheme BrewGUI -destination 'platform=macOS' build
```

## How it works

The codebase is layered — Views → ViewModels → Services → Models — and documented
in depth, including a deep-dive on the async `brew` process runner. See
**[ARCHITECTURE.md](ARCHITECTURE.md)** for a guided, learning-oriented tour.

```
BrewGUI/
├── Services/      Runs brew (BrewProcess) + Homebrew JSON API (BrewAPIClient, APICache)
├── Models/        Plain data: PackageSummary, PackageDetail, API models
├── ViewModels/    Per-screen @Observable brains + the shared OperationCenter
├── Views/         SwiftUI screens + shared components
└── DesignSystem/  Spacing grid, amber palette, IconTile / PackageIcon
```

## Roadmap

- [x] Foundation: async/streaming `BrewProcess`, JSON API client + cache, design system, nav shell
- [x] Installed — redesigned rows, searchable
- [x] Outdated — per-row + bulk upgrade with live log
- [x] Browse — search, real icons, install, pagination
- [x] Package detail pane — description, source, version, deps, install counts
- [x] Operation center — streamed install/uninstall/upgrade log
- [ ] Popular — analytics-ranked discovery
- [ ] Services — start/stop/restart brew services
- [ ] Cleanup — reclaim disk space via `brew cleanup`
- [ ] Health — `brew doctor`, surfaced cleanly

## Disclaimer

BrewGUI is not affiliated with or endorsed by the Homebrew project. It is a
third-party front end that runs the same `brew` commands you would type yourself.

© 2026 mdhesi.
