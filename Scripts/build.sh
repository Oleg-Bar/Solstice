#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p Build/cache Build/products
export CLANG_MODULE_CACHE_PATH="$PWD/Build/cache"
sdk="$(xcrun --show-sdk-path)"
arch="${TERRA_ARCH:-$(uname -m)}"
common=(-sdk "$sdk" -target "$arch-apple-macosx13.0" -swift-version 5 -O -module-cache-path "$PWD/Build/cache" -I Sources/AstronomyC/include)
xcrun clang -O2 -isysroot "$sdk" -target "$arch-apple-macosx13.0" -I Sources/AstronomyC/include -c Sources/AstronomyC/astronomy.c -o Build/astronomy.o
sources=(Sources/Core/*.swift Sources/Rendering/*.swift Sources/UI/*.swift)
app="Build/products/Terra Preview.app"
saver="Build/products/Terra.saver"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$saver/Contents/MacOS" "$saver/Contents/Resources"
xcrun swiftc "${common[@]}" -module-name TerraPreview "${sources[@]}" Sources/Preview/*.swift Build/astronomy.o -o "$app/Contents/MacOS/TerraPreview"
xcrun swiftc "${common[@]}" -module-name TerraSaver -emit-library -Xlinker -bundle "${sources[@]}" Sources/Screensaver/*.swift Build/astronomy.o -o "$saver/Contents/MacOS/TerraSaver"
cp Resources/* "$app/Contents/Resources/"
cp Resources/* "$saver/Contents/Resources/"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>studio.terra.preview</string>
<key>CFBundleName</key><string>Terra Preview</string>
<key>CFBundleExecutable</key><string>TerraPreview</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.01</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSSupportsAutomaticTermination</key><false/>
</dict></plist>
PLIST
cat > "$saver/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>studio.terra.screensaver</string>
<key>CFBundleName</key><string>Terra</string>
<key>CFBundleExecutable</key><string>TerraSaver</string>
<key>CFBundlePackageType</key><string>BNDL</string>
<key>CFBundleShortVersionString</key><string>1.01</string>
<key>CFBundleVersion</key><string>2</string>
<key>NSPrincipalClass</key><string>TerraScreenSaverView</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$app"
codesign --force --sign - "$saver"
codesign --verify --strict "$app"
codesign --verify --strict "$saver"
printf 'Built and signed locally:\n  %s\n  %s\n' "$app" "$saver"
