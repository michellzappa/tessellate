#!/bin/zsh
# Build Tessellate.app and install it to /Applications, signed with the stable
# Apple Development identity from project.yml (so the Accessibility grant
# survives rebuilds). Regenerates the Xcode project and the icon every time.
#
#   ./scripts/build-app.sh            # Release → /Applications/Tessellate.app
#   ./scripts/build-app.sh --debug
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
housekit="${HOUSEKIT_PATH:-$here/../housekit}"
config=Release
[[ "${1:-}" == "--debug" ]] && config=Debug

swift build -c release --package-path "$housekit" >/dev/null
"$(swift build -c release --package-path "$housekit" --show-bin-path)/housekit-icon" tessellate "$here/Tessellate/Resources/AppIcon.icns" >/dev/null

cd "$here"
xcodegen generate --quiet
build="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
xcodebuild -project Tessellate.xcodeproj -scheme Tessellate -configuration "$config" \
  -derivedDataPath build/DerivedData CURRENT_PROJECT_VERSION="$build" \
  CODE_SIGNING_ALLOWED=NO -quiet build
app="build/DerivedData/Build/Products/$config/Tessellate.app"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build" "$app/Contents/Info.plist"
# Local builds carry no provisioning profile, and the iCloud KVS entitlement
# is restricted: launchd refuses to start an app that claims it unprovisioned.
# Sign without it here; the release workflow signs with the profile and keeps it.
entitlements="build/Tessellate.local.entitlements"
cp Tessellate/Resources/Tessellate.entitlements "$entitlements"
/usr/libexec/PlistBuddy -c "Delete :com.apple.developer.ubiquity-kvstore-identifier" "$entitlements" 2>/dev/null || true
codesign --force --sign "Apple Development" --entitlements "$entitlements" --options runtime "$app"

target=/Applications/Tessellate.app
if pgrep -xq Tessellate; then osascript -e 'tell application "Tessellate" to quit' >/dev/null 2>&1 || true; sleep 0.5; fi
rm -rf "$target"
/usr/bin/ditto "$app" "$target"
codesign --verify --strict "$target"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$target/Contents/Info.plist")"
printf '%s (version %s, build %s)\n' "$target" "$version" "$build"
