# Contributing

## Getting set up

You need macOS 13+ and the Xcode Command Line Tools (`xcode-select --install`).
Nothing else — no CocoaPods, no SPM dependencies, no Xcode project.

```sh
git clone https://github.com/X3TSr/Caffeinate-UI.git
cd Caffeinate-UI
swift test          # unit tests for CaffeinateKit
./scripts/run.sh    # debug build, runs in the foreground
```

`./scripts/run.sh` runs the app attached to your terminal, so Ctrl-C stops it — and
because quitting stops the session, it won't leave your Mac awake.

You can also open the package directly in Xcode (`open Package.swift`) and run the
`CaffeinateUI` scheme, though the login item and notifications only work from a real
bundle produced by `./scripts/build.sh`.

## Watching what it does

```sh
log stream --predicate 'subsystem == "com.x3tsr.caffeinate-ui"'   # the app's own log
pmset -g assertions                                               # what macOS thinks
pgrep -lf caffeinate                                              # the child process
```

## Where things go

- Anything with behaviour — command building, session lifecycle, persistence —
  belongs in `Sources/CaffeinateKit` and should come with a test.
- `Sources/CaffeinateUI` should stay declarative. If a view needs a decision made,
  the decision belongs in the Kit or in `AppEnvironment`.
- New `caffeinate` flags go in `CaffeinateOptions` **and** in
  `CaffeinateOptionDescriptor.all` — the UI builds itself from the descriptors, so
  that is all a new toggle needs.

## Style

Match the surrounding code. The short version:

- 4 spaces, no tabs (except in shell scripts and `Makefile`, which use tabs).
- Comments explain *why*, not *what*. If a line needs a comment to say what it does,
  rename something instead.
- Doc comments (`///`) on public API in `CaffeinateKit`; nothing ceremonial on
  private view helpers.
- No force unwraps outside tests.

## Tests

`swift test` must pass before a pull request. Tests may not:

- spawn a real `caffeinate` (use `FakeLauncher`),
- touch `UserDefaults.standard` (use a throwaway suite),
- depend on wall-clock time (use `TestClock`).

## Pull requests

Keep them focused, describe the behaviour change, and say how you verified it on a
real Mac — the unit tests cover the logic but not the menu bar. Screenshots are
welcome for anything visual.

## Releasing

See [docs/RELEASING.md](docs/RELEASING.md).
