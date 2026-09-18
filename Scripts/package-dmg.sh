#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

version="1.10"
build_number="13"
product="Solstice"
release_dir="$PWD/Build/release"
stage="$release_dir/dmg-root"
installer="$stage/Solstice.app"
resources="$installer/Contents/Resources"
hero="$PWD/Docs/GitHub-Previews/Solstice-Retina-5K.png"
background="$stage/.background/background.png"
icon="$release_dir/Solstice.icns"
thumbnail="$release_dir/Solstice-Thumbnail.png"
rw_image="$release_dir/Solstice-$version-rw.dmg"
output="$release_dir/Solstice-$version-macOS-Apple-Silicon.dmg"
volume_name="Solstice $version"

if [[ ! -f "$hero" ]]; then
    printf 'Missing 5K hero image: %s\n' "$hero" >&2
    exit 1
fi

bash Scripts/build.sh

rm -rf "$stage"
rm -f "$rw_image" "$output" "$output.sha256" "$icon" "$thumbnail"
mkdir -p "$resources" "$stage/.background"

# The app header is derived from the verified 5K product render. Native `sips`
# crops only the vertical excess, keeping Earth and the Moon in frame, then
# creates the exact 1440x600 2x asset without launching another Metal process.
sips -c 2133 5120 "$hero" --out "$thumbnail" >/dev/null
sips -z 600 1440 "$thumbnail" >/dev/null

# Customer-facing names are Solstice; internal executable/module names remain stable.
ditto "Build/products/Terra.saver" "$resources/Solstice.saver"
ditto "Build/products/Terra Preview.app" "$resources/Solstice Preview.app"
cp "$hero" "$resources/Hero.png"
cp "$thumbnail" "$resources/SolsticeThumbnail.png"
ln -s /Applications "$stage/Applications"

# Finder background and app icon are derived from the actual 5K product image.
python3 Scripts/create-brand-assets.py "$hero" "$background" "$icon"
cp "$icon" "$installer/Contents/Resources/Solstice.icns"
cp "$icon" "$stage/.VolumeIcon.icns"

sdk="$(xcrun --show-sdk-path)"
arch="${TERRA_ARCH:-$(uname -m)}"
export CLANG_MODULE_CACHE_PATH="$PWD/Build/cache"
mkdir -p "$installer/Contents/MacOS"
xcrun swiftc -parse-as-library -sdk "$sdk" -target "$arch-apple-macosx13.0" -swift-version 5 -O \
    -module-cache-path "$PWD/Build/cache" \
    Sources/Installer/InstallerApp.swift -o "$installer/Contents/MacOS/SolsticeInstaller"

cat > "$installer/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>studio.solstice.app</string>
<key>CFBundleName</key><string>Solstice</string>
<key>CFBundleDisplayName</key><string>Solstice</string>
<key>CFBundleExecutable</key><string>SolsticeInstaller</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$version</string>
<key>CFBundleVersion</key><string>$build_number</string>
<key>CFBundleIconFile</key><string>Solstice</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
</dict></plist>
PLIST

signing_identity="${TERRA_SIGN_IDENTITY:-}"
if [[ -z "$signing_identity" ]]; then
    signing_identity="$(security find-identity -v -p codesigning 2>/dev/null \
        | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' | head -n 1)"
fi
if [[ -n "$signing_identity" ]]; then
    codesign --force --deep --sign "$signing_identity" --options runtime --timestamp "$installer"
else
    codesign --force --deep --sign - --options runtime --timestamp=none "$installer"
    printf 'Warning: DMG is a preview build with an ad-hoc signature.\n' >&2
fi
codesign --verify --deep --strict "$installer"

hdiutil create -quiet -volname "$volume_name" -srcfolder "$stage" -ov -format UDRW "$rw_image"
mount_point="/Volumes/$volume_name"
if [[ -e "$mount_point" ]]; then
    printf 'Volume is already mounted: %s\n' "$mount_point" >&2
    exit 1
fi
hdiutil attach -quiet -nobrowse -noverify "$rw_image"

# Finder metadata is best-effort: the DMG remains fully usable if Automation is denied.
osascript <<APPLESCRIPT || true
tell application "Finder"
    tell disk "$volume_name"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {120, 120, 920, 620}
        set opts to icon view options of container window
        set arrangement of opts to not arranged
        set icon size of opts to 112
        set text size of opts to 13
        set background picture of opts to file ".background:background.png"
        set position of item "Solstice.app" to {180, 275}
        set position of item "Applications" to {620, 275}
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
APPLESCRIPT
SetFile -a C "$mount_point" || true
sync
hdiutil detach -quiet "$mount_point"
hdiutil convert -quiet "$rw_image" -format UDZO -imagekey zlib-level=9 -o "$output"
hdiutil verify "$output" >/dev/null
if [[ -n "$signing_identity" ]]; then
    codesign --force --sign "$signing_identity" --timestamp "$output"
    codesign --verify --verbose "$output"
fi
(
    cd "$release_dir"
    shasum -a 256 "$(basename "$output")" > "$(basename "$output").sha256"
)

rm -f "$rw_image"

printf 'Release image created:\n  %s\n  %s\n' "$output" "$output.sha256"
