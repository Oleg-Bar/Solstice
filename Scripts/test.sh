#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p Build/cache
export CLANG_MODULE_CACHE_PATH="$PWD/Build/cache"
xcrun clang -O2 -I Sources/AstronomyC/include -c Sources/AstronomyC/astronomy.c -o Build/astronomy-tests.o
xcrun swiftc -D DIRECT_TESTS -I Sources/AstronomyC/include -module-cache-path Build/cache Sources/Core/*.swift Tests/TerraCoreTests.swift Scripts/TestRunner.swift Build/astronomy-tests.o -o Build/TerraCoreTests
Build/TerraCoreTests
