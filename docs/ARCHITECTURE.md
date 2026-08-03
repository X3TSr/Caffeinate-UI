# Architecture

## The shape of the thing

Caffeinate UI is a SwiftUI app whose entire job is to run one command well:

```
/usr/bin/caffeinate [-d] [-i] [-m] [-s] [-u] [-t seconds]
```

Everything else — the countdown, the presets, the settings — exists to make that
command convenient. Two design rules follow from this:

1. **The app never lies about what it runs.** The command string in the window is
   built by the same code that builds the process arguments (`CaffeinateCommand`),
   so it cannot drift out of sync.
2. **The app never holds power assertions itself.** It could call `IOPMAssertion`
   directly and skip the subprocess. It doesn't, because then "what is keeping my
   Mac awake?" would have a different answer than the one people already know how to
   check (`pmset -g assertions`, `pgrep caffeinate`).

## Targets

| Target | Contents | Tested |
| --- | --- | --- |
| `CaffeinateKit` | Options, durations, command building, process lifecycle, persistence, preferences | Yes — no UI, no AppKit |
| `CaffeinateUI` | SwiftUI scenes, menu bar panel, window, settings, notifications, login item | No — thin, mostly declarative |

The split exists so the parts with actual behaviour can be tested without a UI host
and without spawning real processes.

## Data flow

```
        Preferences  ──────────────┐  (default flags + duration)
                                   ▼
User action ──► AppEnvironment ──► CaffeinateController ──► ProcessLaunching
                     │                    │                       │
                     │                    │                       └─► /usr/bin/caffeinate
                     │                    ├─► SessionPersisting ──► session.json
                     │                    └─► @Published session / tick
                     │                                 │
                     └─► NotificationManager ◄─────────┘ (onSessionEnded)
                     └─► LoginItemManager (SMAppService)
```

`AppEnvironment` is the only object that knows about all the pieces. Views get three
environment objects — `AppEnvironment` for actions, `CaffeinateController` for live
state, `Preferences` for settings — because nested `ObservableObject`s do not
propagate changes through SwiftUI.

## Key decisions

### `-t` owns the timer, not the app

A timed session passes `-t <seconds>` and lets `caffeinate` end itself. The app's own
one-second timer only drives the countdown label. If the app is suspended, throttled,
or busy, the session still ends exactly on time — the deadline lives in the child
process, not in a `Timer` we might miss.

The trade-off: the duration cannot be changed in place. Changing it (or `+15m`, or
toggling a flag mid-session) restarts `caffeinate` with new arguments. That gap is
sub-second and macOS will not idle sleep inside it.

### Sessions survive the app

If the app crashes or is force quit, its child `caffeinate` is reparented to `launchd`
and keeps running — an invisible process holding your Mac awake with no UI to stop it.

Every start writes `{pid, startDate, duration, options}` to
`~/Library/Application Support/CaffeinateUI/session.json`, and every stop clears it.
On launch, `recoverOrphanedSession()`:

1. reads the record, and verifies the pid is alive **and** is really `caffeinate`
   (via `ps -o comm=`, because pids get recycled);
2. if the session's time has already elapsed, kills it and clears the record;
3. otherwise adopts it — the UI shows the original start time and countdown, and
   Stop sends `SIGTERM` to that pid.

Adopted sessions have no `terminationHandler` (they are not our children), so their
liveness is polled once a second alongside the countdown tick.

### Menu bar first, window when asked

`LSUIElement` is `true`, so the app is an accessory: no Dock icon, no menu bar menus.
Opening the window switches the activation policy to `.regular` so it can take focus
and behave like a normal window; closing it switches back. The "Show an icon in the
Dock" setting pins it to `.regular`.

SwiftUI opens the `Window` scene at launch. The first launch lets it through so the
app is discoverable; later launches close it immediately, which is what you want for
something that starts at login.

### Testing without side effects

`ProcessLaunching` and `SessionPersisting` are protocols. The tests use a fake
launcher that records arguments and hands back fake processes, and an in-memory store
— so the suite asserts on the exact `caffeinate` invocation, on restart-on-change
behaviour, and on all three crash recovery paths without ever keeping the test
machine awake. The clock is injected too, so countdown maths is deterministic.

## Concurrency

`CaffeinateController`, `AppEnvironment` and `LoginItemManager` are `@MainActor`;
they are UI state. The only work off the main actor is `Process.terminationHandler`,
which hops back with `Task { @MainActor in … }`.

The countdown timer is scheduled in `RunLoop.Mode.common` — in `.default` it would
stall whenever a menu is tracking, which for a menu bar app is exactly when you are
looking at it.

## Files worth knowing

| File | Why it matters |
| --- | --- |
| `Sources/CaffeinateKit/CaffeinateController.swift` | The whole session lifecycle |
| `Sources/CaffeinateKit/CaffeinateCommand.swift` | The single source of truth for arguments |
| `Sources/CaffeinateUI/AppEnvironment.swift` | Launch behaviour, activation policy, wiring |
| `Sources/CaffeinateUI/CaffeinateUIApp.swift` | Scenes: menu bar, window, settings |
| `scripts/build.sh` | Turns the SwiftPM binary into a real .app bundle |
| `Resources/Info.plist` | `LSUIElement`, sudden-termination opt-out, versions |
