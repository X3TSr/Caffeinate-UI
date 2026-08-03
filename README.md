<div align="center">

# ☕ Caffeinate UI

**A menu bar app for the macOS `caffeinate` command.**

Keep your Mac awake for a set amount of time, with one click — and see exactly how long is left.

![platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey)
![swift](https://img.shields.io/badge/Swift-5.9-orange)
![license](https://img.shields.io/badge/license-MIT-blue)

</div>

---

## What it is

macOS ships with a perfectly good tool for staying awake:

```sh
caffeinate -d -t 28800    # keep the display on for 8 hours
```

The problem is that it lives in a Terminal window you have to keep open, with a timer
you can't see and a duration you can't change without killing it and typing it again.

Caffeinate UI is a thin, honest wrapper around that command. It runs the *same*
`caffeinate` binary — no daemons, no kernel extensions, no background service, no
private APIs — and gives you a switch, a countdown and a set of checkboxes.

The command being run is always shown in the window. What you see is what executes.

```
      Menu bar                            Window
┌────────────────────────────┐   ┌────────────────────────────┐
│ ☕ Awake        7:42:11    │   │                            │
│ Until 5:30 PM              │   │          ╭────────╮        │
│ ▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░     │   │        ╱     ☕     ╲      │
│ ┌────────────────────────┐ │   │       │   7:42:11    │     │
│ │         Stop           │ │   │        ╲  until 5:30╱      │
│ └────────────────────────┘ │   │          ╰────────╯        │
│ Duration          +15m     │   │                            │
│ [ ∞ ][15m][30m][1h]        │   │  [        Stop      ][+15m]│
│ [2h ][4h ][8h ][Custom]    │   │                            │
│ Keep awake                 │   │  DURATION                  │
│ ☑ Prevent display sleep    │   │  [∞][15m][30m][1h][2h][8h] │
│ ☑ Prevent system sleep     │   │  Custom: 1 h  30 m  [Use]  │
│ ──────────────────────     │   │                            │
│ Open Window  Settings  Quit│   │  KEEP AWAKE                │
└────────────────────────────┘   │  ☑ display -d ☑ system -i  │
                                 │  ▸ Advanced                │
                                 │                            │
                                 │  COMMAND                   │
                                 │  caffeinate -d -i -t 28800 │
                                 └────────────────────────────┘
```

## Features

- **Menu bar first.** A cup icon with a live countdown. Click it, pick a duration, done.
- **A real window too**, with a countdown ring, every option, and a live preview of
  the command.
- **Duration presets** — 15m, 30m, 1h, 2h, 4h, 8h, indefinite — plus a custom
  duration down to the minute, and a `+15m` button to push the end time out.
- **All five caffeinate assertions**, with the two you actually want up front and the
  rest behind an *Advanced* disclosure.
- **Launch at login** via `SMAppService`, and an optional **auto-start** so your Mac
  is awake from the moment you log in.
- **A notification when a timed session ends**, so you know sleep is allowed again.
- **Crash recovery.** If the app is force quit or crashes, the next launch finds the
  orphaned `caffeinate` process and re-attaches to it instead of leaving your Mac
  awake forever with nothing to stop it.
- **No Dock clutter.** Menu bar only by default; the Dock icon appears while a window
  is open, or permanently if you prefer.

## Install

Requires **macOS 13 (Ventura) or later** and the Xcode Command Line Tools.

```sh
git clone https://github.com/X3TSr/Caffeinate-UI.git
cd Caffeinate-UI
./scripts/install.sh          # builds, installs to /Applications, launches it
```

That's it — look for the cup in your menu bar. To install for the current user only,
use `./scripts/install.sh --user` (installs to `~/Applications`).

If you don't have the command line tools yet:

```sh
xcode-select --install
```

### Build without installing

```sh
./scripts/build.sh            # -> build/Caffeinate UI.app
./scripts/build.sh --debug    # faster, unoptimised
./scripts/build.sh --universal  # arm64 + x86_64
open "build/Caffeinate UI.app"
```

Or with `make`: `make`, `make debug`, `make run`, `make install`, `make test`,
`make uninstall`, `make clean`.

### Uninstall

```sh
./scripts/uninstall.sh
```

Removes the app, its preferences, its login item registration, and stops any session
it left running.

## The flags

Every checkbox is one `caffeinate` flag. Nothing is invented, nothing is hidden.

| Flag | UI label | What it does |
| --- | --- | --- |
| `-d` | Prevent display sleep | Keeps the screen on. |
| `-i` | Prevent system sleep | Stops the Mac from idle sleeping. |
| `-m` | Prevent disk sleep | Keeps disks spun up — useful for long transfers. |
| `-s` | Prevent sleep on AC power | Stronger than `-i`, but only honoured while plugged in. |
| `-u` | Declare user active | Wakes the display, as if you had touched the keyboard. |
| `-t` | Duration | Added automatically for timed sessions, omitted for indefinite ones. |

The default is `-d -i` for 8 hours: `caffeinate -d -i -t 28800`.

Want the screen to sleep while a long build finishes? Turn off *Prevent display
sleep* and the app runs `caffeinate -i -t …` instead.

## How it works

```
Caffeinate UI (SwiftUI)
        │
        │  Process(/usr/bin/caffeinate, ["-d", "-i", "-t", "28800"])
        ▼
   caffeinate ──► IOKit power assertions ──► macOS stays awake
```

- The app spawns `caffeinate` as a **child process** and keeps the handle. Stopping a
  session sends `SIGTERM`; quitting the app stops the session first, so you can never
  leave a stray assertion behind by quitting normally.
- Timed sessions pass `-t <seconds>`, so **`caffeinate` owns the timer**, not the app.
  The countdown in the UI is a display of that same deadline.
- The running session (pid, start time, duration, flags) is written to
  `~/Library/Application Support/CaffeinateUI/session.json`. On launch the app checks
  that pid — if it is still a live `caffeinate`, the session is adopted so you can
  stop it; if its time has already elapsed, it is cleaned up.
- Changing the duration or the flags mid-session restarts `caffeinate` with the new
  arguments. There is a sub-second gap where no assertion is held; macOS will not
  sleep in that window.

Check what the system thinks at any time with:

```sh
pmset -g assertions
```

## Settings

| Setting | Default | Notes |
| --- | --- | --- |
| Launch Caffeinate UI at login | Off | Uses `SMAppService`; needs the built .app bundle. |
| Start a session as soon as the app launches | Off | Uses your default duration and flags. |
| Notify me when a timed session ends | On | Local notification, no network. |
| Show the countdown in the menu bar | On | Turn off for just the icon. |
| Show an icon in the Dock | Off | The Dock icon appears while a window is open regardless. |

Defaults for the duration and the flags live in **Settings → Defaults**.

## Troubleshooting

**The menu bar icon isn't there.**
With a lot of menu bar items macOS may hide it. Check with `pgrep -x CaffeinateUI`;
if it is running, free up menu bar space (or use an item manager) and it will appear.

**"Launch at login" won't stick.**
`SMAppService` needs a code signed bundle in a stable location. Install to
`/Applications` with `./scripts/install.sh` rather than running the app from your
Downloads folder or a build directory. The build script applies an ad-hoc signature,
which is enough for local use.

**No notification when the timer ends.**
The first launch asks for permission. If you dismissed it, enable Caffeinate UI under
System Settings → Notifications. Notifications only work from the built .app bundle.

**macOS says the app is from an unidentified developer.**
It is built and signed ad-hoc on your own machine, so this shouldn't appear — but if
you moved a bundle between Macs, right-click the app → Open, or run
`xattr -dr com.apple.quarantine "/Applications/Caffeinate UI.app"`.

**My Mac slept anyway.**
Closing the lid sleeps a Mac regardless of assertions (that is a hardware policy, not
something `caffeinate` overrides). `-s` is also ignored on battery power. Confirm the
assertion is actually held with `pmset -g assertions`.

**Something is keeping my Mac awake and the app is closed.**
`pgrep -x caffeinate` to find it, `pkill -x caffeinate` to stop it. The app's own
crash recovery handles this on next launch.

## Project layout

```
Sources/
  CaffeinateKit/      Command building, session lifecycle, persistence (no UI, fully tested)
  CaffeinateUI/       SwiftUI app: menu bar panel, window, settings
Tests/                Unit tests for CaffeinateKit
Tools/                CoreGraphics app icon generator
scripts/              build / install / run / uninstall
Resources/Info.plist  Bundle metadata, assembled by scripts/build.sh
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the design and the reasoning
behind it, and [CONTRIBUTING.md](CONTRIBUTING.md) to work on it.

## Roadmap

Ideas for after V1 — see [docs/ROADMAP.md](docs/ROADMAP.md) for the full list.

- Global hotkey to toggle a session
- "Keep awake until this app quits" (`caffeinate -w <pid>`)
- Schedules ("every weekday 9–6") and battery-level guards
- Homebrew cask

## License

MIT — see [LICENSE](LICENSE).

`caffeinate` is part of macOS and belongs to Apple. This project just puts a switch
on it.
