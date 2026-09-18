# Solstice 1.10

**Release date:** September 18, 2026

**Build:** 13

**Platform:** macOS 13 or later, Apple silicon

## Highlights

- Fixed the black screen that could appear when Solstice was hosted by the macOS screen saver process. Rendering now follows the `ScreenSaverView` lifecycle instead of relying on the host window's unreliable occlusion state.
- Added **Start and Lock** to `Solstice.app`. It starts the selected screen saver through the system `ScreenSaverEngine`; when macOS is configured to require a password immediately, returning to the session is protected by the system lock screen.
- Turned the installer into a regular `Solstice.app` that is visible in Finder, Launchpad, and Spotlight.
- Added Preview, install/reinstall, Settings, and complete uninstall controls to the application.
- Added a standard Applications shortcut to the DMG for drag-and-drop installation.
- Added a sharp in-app preview image generated from the real Solstice renderer, including the Earth and Moon.
- Added standard `thumbnail.png` and `thumbnail@2x.png` assets to the screen saver bundle. macOS 26 Tahoe currently ignores custom thumbnails for third-party `.saver` bundles and displays its generic blue tile, while the large live preview renders correctly.
- Improved updates by stopping stale Tahoe screen saver host processes after replacing the bundle, allowing macOS to load the new version without signing out.
- Added complete removal of the installed screen saver, Solstice preferences, owned caches, saved application state, and legacy Terra user files before moving the application to the Trash.
- Strengthened lunar validation for Madrid, Singapore, and New York. The tests verify the shared astronomical phase, observer-dependent altitude, azimuth and apparent orientation, plus a reference point from NASA/JPL Horizons DE441.
- Added collision tests that keep city clocks and labels clear of the lunar disc across the macOS city catalogue, multiple display sizes, camera angles, times, and observer locations.

## Validation

- 18 automated tests
- 3,440 assertions
- 0 failures
- Preview and screen saver bundles build successfully with Swift 6.3.3
- The screen saver bundle loads and completes start, stop, restart, and stop lifecycle checks
- Metal rendering verified with a fresh GPU snapshot
- DMG checksum and `hdiutil verify` validation pass
- The built, packaged, installed, and system-selected screen saver binaries are identical
- Manual Start and Lock flow verified with the protected macOS login overlay

## Installation

1. Open `Solstice-1.10-macOS-Apple-Silicon.dmg`.
2. Drag **Solstice** to **Applications**.
3. Open Solstice and select **Install**.
4. In macOS Settings, select **Solstice** under the third-party screen savers section.
5. To protect the session immediately, set **Require password after screen saver begins or display is turned off** to **Immediately** in Lock Screen settings.

## Known limitations

- The local distribution is ad-hoc signed because no Apple Developer ID certificate is installed on the build Mac. Public distribution requires Developer ID signing and Apple notarization.
- macOS controls the small Settings thumbnail, the protected login interface, password timing, idle timing, and display sleep behavior.
- The standard macOS **Lock Screen** command opens the protected login interface directly and does not start a third-party screen saver. Use **Start and Lock** in Solstice when the animation should appear first.
- Multi-display behavior, long-duration energy use, and macOS versions other than 26.6.1 require additional hardware validation.
