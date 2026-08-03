# Releasing

## Version numbers

`VERSION` holds the marketing version (`CFBundleShortVersionString`). The build
number (`CFBundleVersion`) is the commit count, filled in by `scripts/build.sh`, so
it always increases without anyone maintaining it.

```sh
echo "1.1.0" > VERSION
git commit -am "Release 1.1.0"
git tag v1.1.0
```

## Building the artefact

```sh
./scripts/build.sh --universal
```

That produces `build/Caffeinate UI.app` for both Apple Silicon and Intel, ad-hoc
signed. Zip it for distribution:

```sh
ditto -c -k --keepParent "build/Caffeinate UI.app" "Caffeinate-UI-$(cat VERSION).zip"
```

## Signing for other people's Macs

An ad-hoc signature is fine on the machine that built it. To hand the app to someone
else without Gatekeeper complaining, you need a Developer ID certificate:

```sh
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build.sh --universal

xcrun notarytool submit "Caffeinate-UI-$(cat VERSION).zip" \
    --apple-id you@example.com --team-id TEAMID --keychain-profile caffeinate-ui --wait

xcrun stapler staple "build/Caffeinate UI.app"
```

Notarisation requires the hardened runtime, so add `--options runtime` to the
`codesign` call in `scripts/build.sh` when signing with a Developer ID. The app needs
no entitlements: it is not sandboxed and only spawns `/usr/bin/caffeinate`.

Without a certificate, tell people to build it themselves — it is one command and
that is the point of shipping the source.

## Checklist

- [ ] `swift test` passes
- [ ] `./scripts/build.sh` succeeds from a clean checkout (`make clean` first)
- [ ] The app starts, keeps the Mac awake (`pmset -g assertions`), and stops cleanly
- [ ] Force quit while a session runs, relaunch, confirm the session is adopted
- [ ] Launch at login toggles and survives a reboot
- [ ] `CHANGELOG.md` updated
- [ ] Tag pushed
