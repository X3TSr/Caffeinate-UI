#!/usr/bin/env bash
#
# Builds "Caffeinate UI.app" into ./build.
#
#   ./scripts/build.sh                # release build for this Mac
#   ./scripts/build.sh --debug        # faster build, unoptimised
#   ./scripts/build.sh --universal    # arm64 + x86_64
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Caffeinate UI"
EXECUTABLE="CaffeinateUI"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/$APP_NAME.app"
CONFIGURATION="release"
ARCH_FLAGS=()

for argument in "$@"; do
	case "$argument" in
		--debug) CONFIGURATION="debug" ;;
		--release) CONFIGURATION="release" ;;
		--universal) ARCH_FLAGS=(--arch arm64 --arch x86_64) ;;
		-h|--help) sed -n '2,9p' "$0"; exit 0 ;;
		*) echo "unknown option: $argument" >&2; exit 2 ;;
	esac
done

# --- Preconditions ----------------------------------------------------------

if [[ "$(uname -s)" != "Darwin" ]]; then
	echo "error: Caffeinate UI is a macOS app and can only be built on macOS." >&2
	exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
	echo "error: swift not found. Install the Xcode Command Line Tools:" >&2
	echo "         xcode-select --install" >&2
	exit 1
fi

VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
BUILD_NUMBER="$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || echo 1)"

echo "==> Building $APP_NAME $VERSION ($BUILD_NUMBER), $CONFIGURATION"

# --- Compile ----------------------------------------------------------------

swift build \
	--package-path "$ROOT" \
	--configuration "$CONFIGURATION" \
	--product "$EXECUTABLE" \
	${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}

BIN_PATH="$(swift build --package-path "$ROOT" --configuration "$CONFIGURATION" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)"
BINARY="$BIN_PATH/$EXECUTABLE"

if [[ ! -f "$BINARY" ]]; then
	echo "error: expected a binary at $BINARY" >&2
	exit 1
fi

# --- Assemble the bundle ----------------------------------------------------

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BINARY" "$APP/Contents/MacOS/$EXECUTABLE"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist" >/dev/null
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist" >/dev/null

# --- Icon -------------------------------------------------------------------

ICONSET="$BUILD_DIR/AppIcon.iconset"
ICNS="$BUILD_DIR/AppIcon.icns"

if [[ ! -f "$ICNS" || "$ROOT/Tools/GenerateAppIcon.swift" -nt "$ICNS" ]]; then
	echo "==> Rendering the app icon"
	swift "$ROOT/Tools/GenerateAppIcon.swift" "$ICONSET" >/dev/null
	iconutil --convert icns "$ICONSET" --output "$ICNS"
fi
cp "$ICNS" "$APP/Contents/Resources/AppIcon.icns"

# --- Sign -------------------------------------------------------------------

# Ad-hoc signature. Enough for local use, launch at login and notifications;
# distribution to other Macs needs a Developer ID (see docs/RELEASING.md).
SIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
echo "==> Signing with identity: $SIGN_IDENTITY"
codesign --force --sign "$SIGN_IDENTITY" --timestamp=none "$APP" >/dev/null 2>&1 || {
	echo "warning: code signing failed; the app will still run locally." >&2
}

# Make sure Launch Services notices the new build.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
	-f "$APP" >/dev/null 2>&1 || true

echo "==> Done: $APP"
echo "    Run it with:     open \"$APP\""
echo "    Install it with: ./scripts/install.sh"
