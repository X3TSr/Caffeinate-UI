# Security Policy

## Reporting a vulnerability

Please report security issues **privately**, not as a public issue.

Use GitHub's private vulnerability reporting: go to the
[Security tab](https://github.com/X3TSr/Caffeinate-UI/security) and choose
**Report a vulnerability**. That opens a private advisory only you and the
maintainers can see.

Please include what you were running (macOS version, app version from
Settings → About), what you did, and what happened. A proof of concept helps but
is not required.

Expect an acknowledgement within a week. Since this is a small hobby project
maintained in spare time, please allow a reasonable window for a fix before
disclosing publicly.

## Supported versions

| Version | Supported |
| --- | --- |
| Latest release / `main` | Yes |
| Anything older | No — update first, then report if it still reproduces |

## What this app actually does

Knowing the shape of the thing makes it easier to judge what is worth
reporting. Caffeinate UI:

- **Spawns exactly one external process**: `/usr/bin/caffeinate`, from an
  absolute path, with a fixed set of flags built in `CaffeinateCommand`. The
  arguments come from checkboxes and a bounded integer duration — no user
  supplied string is ever passed through, and no shell is involved (`Process`
  with an argument array, not `sh -c`).
- **Makes no network connections.** No telemetry, no analytics, no update
  check, no crash reporting.
- **Installs no daemon, agent, or helper tool.** The `caffeinate` process is a
  child of the app and dies with it. The optional login item is registered
  through `SMAppService`, which is visible and revocable in System Settings →
  General → Login Items.
- **Requires no elevated privileges.** No `sudo`, no privileged helper, no
  entitlements, no TCC prompts beyond the optional notification permission.
- **Writes two things**: preferences under the `com.x3tsr.caffeinate-ui`
  defaults domain, and `~/Library/Application Support/CaffeinateUI/session.json`
  holding the current session's pid, start time, duration and flags. Neither
  contains personal data.
- **Sends `SIGTERM` to one pid** — the one recorded in that state file, and only
  after confirming the process is alive and is really `caffeinate`
  (see `recoverOrphanedSession`).

## In scope

- Command injection or argument injection into the `caffeinate` invocation
- Privilege escalation, or any path to code execution as another user
- The session state file being used to make the app signal an unrelated process
- The login item or bundle being replaceable in a way that gets attacker code
  launched at login
- Anything that causes the app to hold a power assertion the user cannot see
  or stop

## Out of scope

- `caffeinate` itself, and macOS power management — those are Apple's
- Gatekeeper or "unidentified developer" warnings on builds signed ad-hoc.
  That is expected; see [docs/RELEASING.md](docs/RELEASING.md)
- Anything requiring an attacker who already has code execution as your user,
  or physical access to an unlocked Mac
- The app not preventing sleep when you close the lid, or `-s` being ignored on
  battery — those are documented macOS behaviours, not bugs

## Verifying what you install

There are no prebuilt binaries; you build from source. To confirm what you are
running:

```sh
codesign -dv --verbose=4 "/Applications/Caffeinate UI.app"   # signature and identifier
pgrep -lf caffeinate                                          # the child process and its flags
pmset -g assertions                                           # what macOS thinks is holding it awake
log stream --predicate 'subsystem == "com.x3tsr.caffeinate-ui"'
```

If `pgrep` shows flags you did not choose in the UI, that is worth reporting.

## Dependencies

The package has **zero third-party dependencies** — Swift, SwiftUI, AppKit and
the system `caffeinate` binary only. The only supply chain surface is the
GitHub Actions used in CI, which Dependabot watches.

## CI and pull requests from forks

On a public repository, a pull request runs the workflows in *this* repo against
the *contributor's* code. The posture here:

- **No secrets are used by any workflow.** There is nothing for a malicious PR
  to exfiltrate.
- **`GITHUB_TOKEN` is restricted to `contents: read`**, and `checkout` runs with
  `persist-credentials: false`, so no writable credential reaches the runner.
- **Jobs have `timeout-minutes` set**, so an abusive PR cannot occupy a runner
  for the six hour default.
- **The bundle job is skipped for fork pull requests**, because it executes
  `scripts/build.sh`, which the fork controls. Fork PRs still run the full test
  job.
- **`pull_request_target` is deliberately not used** anywhere. It would run
  fork code with access to the base repository's context.

Repository setting to match: **Settings → Actions → General → Fork pull request
workflows → require approval for all external contributors.** The default only
gates first-time contributors.
