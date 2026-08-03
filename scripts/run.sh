#!/usr/bin/env bash
#
# Builds a debug bundle and runs it in the foreground, streaming its logs.
# Ctrl-C stops the app (and any caffeinate session it started).
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Caffeinate UI"

"$ROOT/scripts/build.sh" --debug

APP="$ROOT/build/$APP_NAME.app"
echo "==> Running $APP"
exec "$APP/Contents/MacOS/CaffeinateUI"
