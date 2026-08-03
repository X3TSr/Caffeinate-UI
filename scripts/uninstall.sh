#!/usr/bin/env bash
#
# Removes the app, its login item, and its preferences.
#
set -euo pipefail

APP_NAME="Caffeinate UI"
BUNDLE_ID="com.x3tsr.caffeinate-ui"

echo "==> Quitting Caffeinate UI"
osascript -e "quit app \"$APP_NAME\"" >/dev/null 2>&1 || pkill -x CaffeinateUI || true

for location in "/Applications/$APP_NAME.app" "$HOME/Applications/$APP_NAME.app"; do
	if [[ -d "$location" ]]; then
		echo "==> Removing $location"
		rm -rf "$location"
	fi
done

# Stop only the caffeinate process this app recorded — never any that the user
# started themselves from Terminal.
STATE="$HOME/Library/Application Support/CaffeinateUI/session.json"
if [[ -f "$STATE" ]]; then
	PID="$(sed -n 's/.*"pid"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' "$STATE" | head -1)"
	if [[ -n "${PID:-}" ]] && ps -p "$PID" -o comm= 2>/dev/null | grep -q caffeinate; then
		echo "==> Stopping the caffeinate session left running (pid $PID)"
		kill "$PID" >/dev/null 2>&1 || true
	fi
fi

echo "==> Removing preferences and saved state"
defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
rm -rf "$HOME/Library/Application Support/CaffeinateUI"

echo "Done."
