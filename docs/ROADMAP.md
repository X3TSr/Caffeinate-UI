# Roadmap

V1 is deliberately small: run `caffeinate`, show a countdown, don't lie about it.
Everything below is a candidate for later, roughly in the order it seems worth doing.

## Next

- **Global hotkey** to start/stop without reaching for the menu bar.
- **Keep awake until an app quits** — `caffeinate -w <pid>`, picked from a list of
  running apps. Ideal for "stay awake until this export finishes".
- **Battery guard** — automatically stop, or refuse to start, below a battery
  percentage you choose.
- **Session history** — a small log of when sessions ran and for how long.

## Maybe

- **Schedules** — "awake every weekday 09:00–18:00" without touching the menu bar.
- **Trigger on conditions** — while a specific app is frontmost, while an external
  display is connected, while on AC power.
- **Menu bar appearance options** — icon only, icon plus percentage, custom symbol.
- **Homebrew cask** so `brew install --cask caffeinate-ui` works.
- **Localisation.** The UI text is short and centralised enough to make this cheap.

## Explicitly not planned

- **Replacing `caffeinate` with direct `IOPMAssertion` calls.** It would remove a
  subprocess, but it would also make the app the thing keeping your Mac awake in a
  way that `pgrep caffeinate` can no longer explain. The transparency is the feature.
- **A background helper or launch daemon.** The app is the session's owner; quitting
  it should end the session, not orphan it into a daemon.
- **Sandboxing / App Store distribution.** Spawning `/usr/bin/caffeinate` is not
  permitted in the sandbox, and the workarounds all involve becoming the kind of app
  the previous point rules out.
