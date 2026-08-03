#!/usr/bin/env bash
#
# Builds the app and installs it into /Applications.
#
#   ./scripts/install.sh              # install to /Applications
#   ./scripts/install.sh --user       # install to ~/Applications
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Caffeinate UI"
DESTINATION="/Applications"

for argument in "$@"; do
	case "$argument" in
		--user) DESTINATION="$HOME/Applications" ;;
		-h|--help) sed -n '2,6p' "$0"; exit 0 ;;
		*) echo "unknown option: $argument" >&2; exit 2 ;;
	esac
done

"$ROOT/scripts/build.sh"

SOURCE="$ROOT/build/$APP_NAME.app"
TARGET="$DESTINATION/$APP_NAME.app"

mkdir -p "$DESTINATION"

# Quit a running copy first so the bundle is not replaced underneath it.
if pgrep -x "CaffeinateUI" >/dev/null 2>&1; then
	echo "==> Quitting the running copy"
	osascript -e 'quit app "Caffeinate UI"' >/dev/null 2>&1 || pkill -x CaffeinateUI || true
	sleep 1
fi

echo "==> Installing to $TARGET"
rm -rf "$TARGET"
cp -R "$SOURCE" "$TARGET"

echo "==> Launching"
open "$TARGET"

echo "Done. Look for the cup in your menu bar."
