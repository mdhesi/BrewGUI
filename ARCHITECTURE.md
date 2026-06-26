# BrewGUI — How This Project Works

A guided tour of the codebase, written to be read top-to-bottom if you're
learning Swift. It assumes you know a little programming but not much Swift or
SwiftUI. Wherever a Swift-specific idea shows up for the first time, there's a
short **"Swift note"** explaining it.

If you got lost "around the refactor where processes got created," start with
[3. The heart: `BrewProcess`](#3-the-heart-brewprocess) — that refactor is
exactly what that section explains.

---

## 1. What the app is, in one breath

BrewGUI is a **native Mac window in front of the `brew` command-line tool.**

Everything you can do in the app maps onto something you could type in a
terminal:

| You click…              | The app runs…                          |
| ----------------------- | -------------------------------------- |
| Installed tab loads     | `brew list --versions`                 |
| Remove on a row         | `brew uninstall --formula <name>`      |
| Outdated tab loads      | `brew update` then `brew outdated`     |
| Upgrade All             | `brew upgrade`                         |
| Reinstall (in History)  | `brew install <name>`                  |

There's also a **second data source**: Homebrew publishes a public JSON API at
`https://formulae.brew.sh/api/` with descriptions, popularity counts, sizes,
etc. The app fetches that over HTTP (this is what the future **Browse** screen
will use). So there are two ways the app gets data:

```
                 ┌─────────────────────────┐
                 │        BrewGUI           │
                 └─────────────────────────┘
                    │                    │
       runs the     │                    │   HTTP GET
       brew binary  │                    │   (URLSession)
                    ▼                    ▼
            ┌──────────────┐     ┌─────────────────────┐
            │  /opt/.../brew│     │ formulae.brew.sh/api │
            │  (subprocess) │     │  (JSON over network) │
            └──────────────┘     └─────────────────────┘
            "what's on THIS       "what EXISTS in
             machine right now"    Homebrew, globally"
```

---

## 2. The layered architecture (the big picture)

The code is split into layers, each in its own folder under `BrewGUI/`. The
golden rule: **a layer may only talk to the layer below it.** Views never launch
a subprocess directly; they ask a ViewModel, which asks a Service.

```
┌──────────────────────────────────────────────────────────────┐
│  Views/            SwiftUI screens. Buttons, lists, layout.   │  ← what you see
│  (InstalledView, OutdatedView, ContentView, PackageRow…)      │
└───────────────┬──────────────────────────────────────────────┘
                │ reads state from / calls methods on
┌───────────────▼──────────────────────────────────────────────┐
│  ViewModels/       The "brain" of each screen. Holds state,   │  ← decisions
│  (InstalledModel, OutdatedModel, OperationCenter…)            │     & state
└───────────────┬──────────────────────────────────────────────┘
                │ calls
┌───────────────▼──────────────────────────────────────────────┐
│  Services/         Talks to the outside world: runs brew,     │  ← the outside
│  (BrewProcess, BrewAPIClient, APICache)                       │     world
└───────────────┬──────────────────────────────────────────────┘
                │ produces / consumes
┌───────────────▼──────────────────────────────────────────────┐
│  Models/           Plain data. Structs that hold values.      │  ← the nouns
│  (PackageSummary, InstalledPackage, APIFormula…)             │
└──────────────────────────────────────────────────────────────┘

  DesignSystem/   Shared visual constants (spacing, colors, the IconTile).
                  Used by Views. Not a "layer" so much as a toolbox.
```

Why bother with layers? Because it means you can understand one piece without
holding the whole app in your head. When the Remove button misbehaves, you know
the bug is in `InstalledView` (the button), `InstalledModel` (the logic), or
`BrewProcess` (the subprocess) — and nowhere else.

> **Swift note — folders vs. modules.** These folders are just organization.
> In this project every file is in the *same* build target, so any file can see
> any other file's types without `import`. The folders are for humans. (The
> `import SwiftUI` / `import Foundation` lines at the top of files import
> *Apple's* frameworks, not other files in this project.)

---

## 3. The heart: `BrewProcess`

**File: `BrewGUI/Services/BrewProcess.swift`**

This is the file the refactor commit
("*Made running process duplicable for future processes*") created. Before that
commit there was a single-purpose `CommandRunner`; the refactor generalized it
into `BrewProcess` so any brew command can be run the same way. Everything the
app *does* to your machine goes through here. Understand this file and the rest
falls into place.

### 3.1 What "running a process" even means

When you type `brew list` in a terminal, the OS:

1. Starts a **new program** (the `brew` binary is a separate executable).
2. Lets it run, while it prints text.
3. Waits for it to **finish** and gives back an **exit code** (`0` = success,
   anything else = failure).

A GUI app does the exact same thing, just without a terminal. macOS gives us a
class called **`Process`** to start another program, and **`Pipe`** to capture
the text it prints. That's the whole idea: BrewGUI is a program that *launches
another program* (`brew`) and reads what it says.

```swift
let process = Process()
process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")
process.arguments = ["list", "--versions"]   // the words after "brew"

let outPipe = Pipe()
process.standardOutput = outPipe   // capture stdout into our pipe
try process.run()                  // GO
process.waitUntilExit()            // block until brew is done
let data = outPipe.fileHandleForReading.readDataToEndOfFile()
```

`Process` = "launch a program." `Pipe` = "a tube I can read the program's output
out of." `arguments` = everything you'd type after `brew`.

### 3.2 Finding `brew` (the discovery part)

Homebrew lives in a different place on Apple Silicon vs. Intel Macs:

```swift
static var brewPath: String {
    let candidates = ["/opt/homebrew/bin/brew",   // Apple Silicon
                      "/usr/local/bin/brew"]      // Intel
    return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
        ?? candidates[0]
}
```

`candidates.first { … }` returns the first path where that `{ … }` test is true
— i.e. the first brew binary that actually exists. `isBrewInstalled` reuses this
to decide whether to show the app or the "install Homebrew" onboarding screen.

> **Swift note — `static var` and trailing closures.** `static` means it belongs
> to the *type* `BrewProcess` itself, not to an instance — you call
> `BrewProcess.brewPath`, you never make a `BrewProcess()` object. The
> `{ FileManager… }` in braces is a **closure** (an anonymous function) passed to
> `.first`. When a closure is the last argument, Swift lets you write it outside
> the parentheses — that's "trailing closure" syntax.

### 3.3 Why everything is `async`

Here's the thing that probably tripped you up. Look at the signatures:

```swift
static func run(_ arguments: [String]) async -> BrewResult
```

That `async` keyword is the big change. **Why?**

`brew install ffmpeg` can take 30 seconds. If we ran it the simple
`waitUntilExit()` way *on the main thread*, the entire UI would **freeze** for
those 30 seconds — no scrolling, no spinner, a beachball. Unacceptable.

`async` is Swift's way of saying: *"this function takes a while; let the app keep
living while it runs, and come back to me when it's done."* A caller uses
`await` to call it:

```swift
let result = await BrewProcess.run(["list", "--versions"])
//           ^^^^^ "pause HERE until brew finishes, but don't freeze the app"
```

While the app is `await`ing, the UI thread is free to animate, scroll, respond
to clicks. When `brew` finishes, execution resumes right after the `await`.

> **Swift note — async/await.** A function marked `async` can be "paused" without
> blocking the thread. You can only call it from inside another `async` function
> or a `Task { … }`. `await` marks the spot where the pause can happen. Think of
> `await` as "this might take a while — wake me when there's an answer." It is
> *not* the app freezing; it's the opposite.

### 3.4 The two ways to run brew

`BrewProcess` offers **two** functions, and knowing when each is used clears up a
lot:

#### `run(...)` — "do it and give me the final result"

Used for **quick commands where we only care about the end result**: listing
packages, uninstalling, checking what's outdated. You get back one `BrewResult`:

```swift
struct BrewResult {
    let stdout: String   // normal output
    let stderr: String   // error output
    let exitCode: Int32  // 0 = success
    var succeeded: Bool { exitCode == 0 }
}
```

Inside `run`, there's some careful plumbing worth knowing about:

- **`withCheckedContinuation`** — `Process` is old Apple tech that doesn't speak
  `async` natively; it speaks "call me back later." `withCheckedContinuation`
  is the **bridge** between the two worlds. It hands you a `continuation` object;
  you call `continuation.resume(returning: …)` whenever the old-style work
  finishes, and that becomes the return value of the `async` function. It's the
  standard recipe for wrapping any callback-based API in async/await.

- **Draining two pipes on separate queues** — we read stdout *and* stderr at the
  same time, on background queues, joined by a `DispatchGroup`. The comment in
  the code explains why: if you read one pipe fully before the other, and the
  program fills the *other* pipe's buffer in the meantime, both sides freeze
  forever waiting on each other (a classic deadlock). Reading both at once
  avoids it. You rarely need to think about this — it's plumbing — but that's
  what those `DispatchQueue.global().async { … }` blocks are doing.

#### `stream(...)` — "run it and feed me each line as it happens"

Used for **long commands where we want to show live output**: install, upgrade.
Instead of waiting for the end, it emits lines *as brew prints them*, so the
log panel scrolls in real time. It returns an **`AsyncStream`**:

```swift
for await event in BrewProcess.stream(["upgrade", "node"]) {
    switch event {
    case .line(let line):  current?.lines.append(line)   // a new line arrived
    case .finished(let code): /* brew exited */
    }
}
```

> **Swift note — `AsyncStream` and `for await`.** A normal `for` loops over a
> collection that already exists. A `for await` loops over values that arrive
> *over time* — here, one per line of brew's output. The loop body runs again
> each time a new value shows up, and ends when the stream finishes. `AsyncStream`
> is just "an async sequence you build yourself"; inside `stream(...)` you'll see
> `continuation.yield(.line(...))` — that's how each value gets pushed into the
> loop.

The mechanism: `stream` attaches a `readabilityHandler` to each pipe — a closure
the OS calls *every time new output is available*. Each chunk is split into lines
and `yield`ed into the stream. When the process ends, `terminationHandler`
fires, yields `.finished(exitCode:)`, and closes the stream.

### 3.5 The shared environment

Both functions configure `process.environment` the same way (the private
`environment` property):

```swift
env["PATH"] = "<brew's bin>:/usr/bin:/bin:…" + existing PATH   // so brew finds git, curl
env["HOMEBREW_NO_AUTO_UPDATE"] = "1"   // don't silently auto-update on every call
env["HOMEBREW_NO_ENV_HINTS"] = "1"     // suppress chatty hint output
```

A subprocess inherits a set of environment variables (like `PATH`, which is how
the shell finds programs). Because the GUI app's environment is *not* your
shell's, we have to set these up by hand so `brew` behaves the way it does in
your terminal.

**That's the whole file.** Two ways to run brew (`run` for results, `stream` for
live logs), plus binary discovery and environment setup. Everything else in the
app is built on these two functions.

---

## 4. The other Service: talking to the web (`BrewAPIClient` + `APICache`)

**Files: `BrewGUI/Services/BrewAPIClient.swift`, `APICache.swift`**

The second data source. Where `BrewProcess` runs a local program, these fetch
JSON over the internet from `formulae.brew.sh`. **This is the layer the Browse
screen will lean on — and the reason you do *not* need Vapor** (see §9).

### 4.1 The fetch + cache pattern

Every call goes through one generic function, `cachedFetch`. Its logic:

```
1. Is there a recent-enough cached copy on disk?  → return it, no network.
2. Otherwise download it, decode the JSON, save to cache, return it.
3. If the download FAILS (offline?)  → return the last cached copy anyway.
```

That last point is why the app still works on a plane: a network error falls back
to whatever was cached last.

```swift
let (data, response) = try await session.data(from: url)  // URLSession = HTTP client
let value = try JSONDecoder().decode(T.self, from: data)  // JSON text → Swift struct
```

> **Swift note — generics (`<T: Codable>`).** `cachedFetch<T: Codable>(...)` works
> for *any* type `T`, as long as `T` is `Codable`. So the same function fetches a
> list of formulae, a list of casks, or an analytics blob — no duplication. The
> caller decides what `T` is by passing the type, e.g. `[APIFormula].self`.
>
> **`Codable`** is the magic that turns JSON into Swift structs (and back). If a
> struct's properties match the JSON keys and it's marked `Codable`, Swift
> generates all the parsing for you. That's why `APIFormula` in `Models/` just
> lists `name`, `desc`, `homepage`, … — those names *are* the JSON keys.

### 4.2 `APICache` is an `actor`

The on-disk cache (`~/Library/Application Support/BrewGUI/cache/`) is declared
`actor APICache`, not `class`.

> **Swift note — `actor`.** An `actor` is like a class, but Swift guarantees only
> one task touches its insides at a time. Several screens might fetch at once;
> without that guarantee two fetches could write the same cache file
> simultaneously and corrupt it. The `actor` makes that impossible — which is
> also why you must `await` when calling its methods (`await cache.load(...)`):
> you might have to wait your turn.

---

## 5. Models — the nouns

**Files: `BrewGUI/Models/PackageModels.swift`, `BrewGUI/InstalledPackage.swift`**

These are plain data. No logic to speak of — just `struct`s that bundle related
values together. A few you'll meet:

- `InstalledPackage` — name + version + "is it a cask?" One row on the Installed
  screen.
- `PackageSummary` — a lightweight Browse row (token, display name, kind,
  description, optional install count).
- `PackageDetail` — everything a detail pane would show.
- `APIFormula` / `APICask` — mirror the JSON shape from the web API; `Codable`.

> **Swift note — `struct` vs `class`.** Almost everything here is a `struct`.
> Structs are **value types**: when you pass one around, you get a *copy*, not a
> shared reference. This is great for data — two parts of the app can't
> accidentally mutate the same package behind each other's backs. The app uses
> `class` only for the few things that need to be *shared and observed* (the
> ViewModels — next section).

> **Swift note — computed properties.** `var id: String { kind.rawValue + "/" + token }`
> looks like a stored value but isn't — the `{ … }` means it's *computed* fresh
> each time you read it. `InstalledPackage.subtitle` is another: it derives the
> grey secondary line from the version. No storage, just a formula.

---

## 6. ViewModels — the brain of each screen

**Files: `BrewGUI/ViewModels/*.swift` plus `RemovalHistoryStore.swift`**

A ViewModel holds **all the state and logic for one screen**, so the View can
stay dumb (just "draw whatever the ViewModel says"). They all share a shape:

```swift
@MainActor
@Observable
final class InstalledModel {
    private(set) var packages: [InstalledPackage] = []   // the data the view draws
    var isLoading = false                                 // for the spinner
    var errorMessage: String?                             // for the alert

    func load() async { … }            // fetch packages via BrewProcess
    func uninstall(_ pkg:) async { … } // remove one, then reload
}
```

> **Swift note — `@Observable` and `@MainActor`.**
> - **`@Observable`** is the modern SwiftUI magic that says "watch this object;
>   when any property changes, redraw the views that read it." You don't call
>   "refresh the UI" anywhere — you just change `packages`, and SwiftUI notices.
> - **`@MainActor`** pins the class to the main thread (where UI must happen). So
>   even though `load()` does background network/subprocess work via `await`, the
>   moment it assigns `packages = …`, that assignment is back on the main thread,
>   safely. It's why you don't see manual "dispatch back to main" code.
> - **`@StateObject` / `ObservableObject` / `@Published`** (seen in
>   `RemovalHistoryStore`) are the *older* generation of the same idea. This
>   project has both because it was written across that transition. They do the
>   same job; `@Observable` is just the newer, lighter syntax.

Read `InstalledModel.load()` as a model of the pattern:

```swift
func load() async {
    guard !isLoading else { return }          // don't double-load
    isLoading = true
    defer { isLoading = false }               // ALWAYS turn the spinner off on exit

    async let formulae = BrewProcess.run(["list", "--versions"])
    async let casks    = BrewProcess.run(["list", "--cask", "--versions"])
    let (f, c) = await (formulae, casks)      // run BOTH at once, then wait for both

    packages = (parse(f) + parse(c)).sorted { … }   // assign → SwiftUI redraws
}
```

> **Swift note — `defer` and `async let`.**
> - **`defer { … }`** runs its block when the function exits, *no matter how* it
>   exits. Perfect for "turn the spinner off" — you can't forget it.
> - **`async let`** kicks off work *without* waiting yet. The two `brew list`
>   calls run **in parallel**; `await (formulae, casks)` then waits for both.
>   Faster than doing them one after another.

### 6.1 `OperationCenter` — the shared one

`OperationCenter` is special: it's **one shared instance** for the whole app (not
one per screen), injected into the environment in `ContentView`. Any screen can
call `operations.run(title:arguments:)` to launch a streamed brew command, and
the **log panel** (`OperationLogView`) automatically reflects it — because they
both read the same `OperationCenter`.

This is why install (future Browse), upgrade (Outdated), and reinstall (History)
all show the same live log sheet: they funnel through this one object. It's also
where the **untrusted-tap "Trust & Retry"** logic lives (it watches the streamed
output for that specific failure and offers a recovery).

> **Swift note — dependency injection via `.environment`.** In `ContentView` you'll
> see `.environment(operations)`. That puts the object into a shared bag that any
> child view can pull out with `@Environment(OperationCenter.self) private var
> operations`. It's how one object is shared across many screens without passing
> it down by hand through every initializer.

### 6.2 `RemovalHistoryStore` — persistence

Stores the list of removed packages to a JSON file in Application Support so
History survives relaunches. `record()` on uninstall, `clear()` after reinstall.
It's the older `ObservableObject` style, but conceptually identical to the
`@Observable` ViewModels.

---

## 7. Views — what you actually see

**Files: `BrewGUI/Views/*.swift`, `ContentView.swift`, `PackageRow.swift`**

SwiftUI is **declarative**: you don't write "create a label, set its text, add it
to the row." You *describe* what the screen should look like *for the current
state*, and SwiftUI builds and updates it. Change the state → the description is
re-evaluated → the screen updates. That's the entire model.

### 7.1 The shell: `ContentView`

`ContentView` is the frame everything lives in. It:

1. Checks `BrewProcess.isBrewInstalled` — if not, shows `OnboardingView` instead.
2. Otherwise builds a **`NavigationSplitView`**: the sidebar on the left, the
   selected screen on the right.
3. The `selection` state (`@State private var selection: SidebarItem?`) decides
   which screen `detail` shows, via a `switch`.

```swift
@ViewBuilder private var detail: some View {
    switch selection ?? .browse {
    case .installed: InstalledView()
    case .outdated:  OutdatedView()
    case .browse:    PlaceholderScreen(…)   // ← you'll replace this for Browse
    …
    }
}
```

> **Swift note — `@State` and `some View`.**
> - **`@State`** marks a piece of state *owned by this view*. When it changes, the
>   view re-renders. `selection` is `@State`, so picking a sidebar item redraws
>   the detail pane automatically.
> - **`some View`** means "this returns *a* view, the compiler knows the exact
>   type but I don't have to write it." Every SwiftUI view's `body` returns
>   `some View`.

### 7.2 A screen: `InstalledView`

A typical screen wires a ViewModel to a list:

```swift
struct InstalledView: View {
    @State private var model = InstalledModel()       // owns its brain
    @State private var searchText = ""

    var body: some View {
        List {
            ForEach(filtered) { pkg in
                PackageRow(package: pkg,
                           isBusy: model.busy.contains(pkg.id),
                           onRemove: { Task { await model.uninstall(pkg, …) } })
            }
        }
        .searchable(text: $searchText, …)             // the toolbar search field
        .task { if model.packages.isEmpty { await model.load() } }  // load on first show
    }
}
```

Notice the division of labor: the **View** decides *layout* (a list of rows, a
search field, a refresh toolbar button) and the **ViewModel** decides *behavior*
(what "load" and "uninstall" mean). The view never touches `BrewProcess`.

> **Swift note — `.task`, `Task { }`, and `$`.**
> - **`.task { … }`** runs an async job when the view appears (and cancels it if
>   the view disappears). It's the standard "load data on screen open" hook.
> - **`Task { await … }`** starts a new async job from a *non-async* spot — like a
>   button's tap handler, which isn't itself async.
> - **`$searchText`** (with the dollar sign) is a **binding** — a two-way
>   connection. The search field both *reads* and *writes* `searchText`, so as you
>   type, the variable updates and the list re-filters.

### 7.3 A reusable piece: `PackageRow`

One row: a leading `IconTile`, the name, a grey secondary line, and a
**hover-revealed** Remove button (per the project's design rule that destructive
actions never sit as a permanent button on every row). `@State private var
isHovering` drives that reveal.

### 7.4 The log: `OperationLogView`

The sheet that pops up during install/upgrade/reinstall. It reads the shared
`OperationCenter` and redraws as new log lines stream in — including the
"Trust & Retry" banner when a brew op hits an untrusted tap.

---

## 8. Two end-to-end walkthroughs

Tracing one action through every layer is the fastest way to feel the
architecture. Follow the arrows.

### 8.1 App launch → Installed list appears

```
BrewGUIApp.swift            the @main entry point; shows ContentView
   └─ ContentView           brew installed? → yes → NavigationSplitView
        └─ InstalledView    .task fires → calls model.load()
             └─ InstalledModel.load()        sets isLoading = true (spinner shows)
                  └─ BrewProcess.run(["list","--versions"])   launches the subprocess
                       └─ /opt/homebrew/bin/brew prints package list
                  ◀── BrewResult(stdout: "wget 1.21\nffmpeg 6.0\n…")
             parse → [InstalledPackage] → assign to model.packages
        ◀── @Observable notices packages changed → SwiftUI redraws the List
   you see your packages; spinner hides (defer set isLoading = false)
```

### 8.2 Clicking "Remove" on a row

```
PackageRow Remove button → onRemove() closure
   └─ Task { await model.uninstall(pkg, history) }   (InstalledView wired this up)
        └─ InstalledModel.uninstall()
             busy.insert(pkg.id)            row shows a spinner instead of Remove
             └─ BrewProcess.run(["uninstall","--formula","wget"])
                  ◀── succeeded
             history.record("wget")         RemovalHistoryStore writes JSON to disk
             await load()                   reload the list (wget now gone)
        ◀── packages changes → list animates the row out (spring animation)
```

If the uninstall *fails*, `errorMessage` is set instead, and `InstalledView`'s
`.alert` shows brew's actual error — never a silent failure.

---

## 9. Building the Browse screen (what's next)

Your instinct was to reach for **Vapor** and "send requests to the brew page."
Here's the correction, and the actual plan:

- **Vapor is a *server* framework** — you use it to *build* a web API (write the
  thing that answers HTTP requests). You want to *consume* an API that already
  exists. Different job. You need an HTTP **client**, and Swift already has a
  great one built in: **`URLSession`** — which `BrewAPIClient` already wraps.
- **Don't scrape the brew web page either.** Homebrew publishes structured JSON
  at `formulae.brew.sh/api/` precisely so apps don't have to scrape HTML.
  `BrewAPIClient.allFormulae()` and `allCasks()` already fetch it (and cache it).

So Browse is mostly **wiring existing pieces together**, not new infrastructure:

1. **A `BrowseModel` ViewModel** (`@MainActor @Observable`), mirroring
   `InstalledModel`. On appear, call:
   ```swift
   let formulae = await BrewAPIClient.shared.allFormulae()
   let casks    = await BrewAPIClient.shared.allCasks()
   ```
   Map them to `[PackageSummary]` (each API type already has a `.summary`).
2. **Search** — filter that big list by `searchText` (same `.searchable` pattern
   as `InstalledView`). The full catalog is ~tens of thousands of items, so
   filter on a background task and/or cap results; don't rebuild on every
   keystroke without thought.
3. **Popularity ranking** — `BrewAPIClient.analytics(kind:period:)` returns
   install counts; sort by those for a "Popular" view.
4. **A `BrowseView`** — replace the `PlaceholderScreen` for `.browse` in
   `ContentView` with a real list of `PackageSummary` rows (reuse the `IconTile`
   look from `PackageRow`).
5. **Install action** — a row's Install button calls
   `operations.run(title: "Installing \(token)", arguments: ["install", token])`.
   That reuses `OperationCenter`, so you get the live log **and** the
   untrusted-tap "Trust & Retry" handling for free.

In other words: the Services and Models for Browse already exist. The work is one
ViewModel and one View, following the exact patterns in `InstalledView` /
`InstalledModel`.

---

## 10. Swift concepts cheat-sheet

Quick reference for the terms used above.

| Term                    | One-liner                                                            |
| ----------------------- | ------------------------------------------------------------------- |
| `struct`                | Value type. Copied when passed. Used for data.                      |
| `class`                 | Reference type. Shared. Used for things that must be observed.      |
| `enum`                  | A fixed set of cases (e.g. `PackageKind.formula` / `.cask`).        |
| `async` / `await`       | "This takes a while; pause without freezing the app."               |
| `Task { }`              | Start async work from non-async code (e.g. a button tap).           |
| `actor`                 | A class that's safe to touch from many tasks at once.               |
| `@Observable`           | "Watch this object; redraw views when it changes." (modern)         |
| `ObservableObject`/`@Published` | Same idea, older syntax (`RemovalHistoryStore`).            |
| `@State`                | View-owned state; changing it re-renders the view.                  |
| `@Environment`          | Pull a shared object the app put into the environment bag.          |
| Binding (`$value`)      | Two-way connection (search field ↔ variable).                       |
| `Codable`               | Auto-converts between JSON and Swift structs.                       |
| Generics (`<T>`)        | Write a function once, works for many types.                        |
| `some View`             | "A view; compiler knows the type, I don't have to name it."         |
| `defer`                 | Run this when the function exits, no matter how.                    |
| `async let`             | Start parallel work, `await` the results together.                  |
| `AsyncStream`/`for await` | Loop over values that arrive over time (live log lines).          |
| `Process` / `Pipe`      | Launch another program / capture its output.                        |
| `withCheckedContinuation` | Bridge an old callback-style API into async/await.                |

---

## 11. File-by-file index

```
BrewGUI/
├── BrewGUIApp.swift          @main entry point. Shows ContentView.
├── ContentView.swift         App shell: sidebar + NavigationSplitView + routing.
│
├── Services/                 Talks to the outside world.
│   ├── BrewProcess.swift     ★ Runs the brew binary (run + stream). Start here.
│   ├── BrewAPIClient.swift   Fetches formulae.brew.sh JSON (for Browse).
│   └── APICache.swift        On-disk cache (an actor) for those responses.
│
├── Models/                   Plain data.
│   ├── PackageModels.swift   PackageSummary, PackageDetail, API* (Codable), analytics.
│   └── (InstalledPackage.swift lives at top level)
├── InstalledPackage.swift    One installed formula/cask row model.
│
├── ViewModels/               Per-screen brains (@Observable).
│   ├── InstalledModel.swift  Loads + uninstalls installed packages.
│   ├── OutdatedModel.swift   Lists outdated; per-row + bulk upgrade.
│   └── OperationCenter.swift ★ Shared. Streamed install/upgrade + Trust & Retry.
├── RemovalHistoryStore.swift Persists removal history to JSON (ObservableObject).
│
├── Views/                    SwiftUI screens.
│   ├── InstalledView.swift   The Installed screen.
│   ├── OutdatedView.swift    The Outdated screen.
│   ├── HistoryView.swift     Removed packages + reinstall.
│   ├── OnboardingView.swift  Shown when brew isn't installed; + PlaceholderScreen.
│   └── OperationLogView.swift The live log sheet (+ Trust & Retry banner).
├── PackageRow.swift          Reusable two-line row with hover-reveal Remove.
├── CheckingProgressBar.swift The animated "checking for updates" bar.
│
└── DesignSystem/
    └── DesignSystem.swift     Spacing grid, Theme, BrewColor palette, IconTile.
```

★ = the two files to read first if you want to understand how the app *works*.

---

### Where to go from here

1. Re-read **`BrewProcess.swift`** with §3 open beside it. That's the engine.
2. Then **`InstalledModel.swift`** + **`InstalledView.swift`** together (§6, §7) —
   one screen, top to bottom.
3. Then build **Browse** by copying that pair's shape but sourcing data from
   `BrewAPIClient` instead of `BrewProcess` (§9).
