#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p Build/cache
export CLANG_MODULE_CACHE_PATH="$PWD/Build/cache"
sdk="$(xcrun --show-sdk-path)"
arch="${TERRA_ARCH:-$(uname -m)}"
target="$arch-apple-macosx13.0"
xcrun clang -O2 -isysroot "$sdk" -target "$target" -I Sources/AstronomyC/include -c Sources/AstronomyC/astronomy.c -o Build/astronomy-tests.o
xcrun swiftc -D DIRECT_TESTS -sdk "$sdk" -target "$target" -swift-version 5 -I Sources/AstronomyC/include -module-cache-path Build/cache Sources/Core/*.swift Tests/TerraCoreTests.swift Scripts/TestRunner.swift Build/astronomy-tests.o -o Build/TerraCoreTests
Build/TerraCoreTests
