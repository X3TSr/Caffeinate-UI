# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] — 2026-08-03

First release.

### Added

- Menu bar item with a live countdown, start/stop, duration presets and the two
  common assertions.
- Main window with a countdown ring, custom duration entry, all five `caffeinate`
  flags, and a live preview of the command being run.
- Duration presets (15m, 30m, 1h, 2h, 4h, 8h, indefinite), custom durations from one
  minute to 24 hours, and a `+15m` extend button.
- Settings: launch at login (`SMAppService`), auto-start a session on launch,
  notification when a timed session ends, menu bar countdown toggle, Dock icon
  toggle, and defaults for the duration and flags.
- Crash recovery: an orphaned `caffeinate` process from a previous launch is adopted
  (or cleaned up if its time already elapsed) instead of being left running.
- `scripts/build.sh`, `install.sh`, `run.sh`, `uninstall.sh` and a `Makefile`;
  the app icon is generated with CoreGraphics at build time.
- Unit tests for command building, durations, preferences, session persistence and
  the full session lifecycle including all recovery paths.

[Unreleased]: https://github.com/X3TSr/Caffeinate-UI/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/X3TSr/Caffeinate-UI/releases/tag/v1.0.0
