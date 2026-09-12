# Changelog

## v0.2.3

### Fixed

- Prevented the installer from launching duplicate WorkMeter menu-bar instances.
- The installer now checks whether the installed WorkMeter process is already running before using LaunchServices or the direct-binary fallback.

## v0.2.2

### Fixed

- Improved macOS installer startup handling.
- Added stronger app bundle validation before installation.
- Improved LaunchAgent startup compatibility.
- Added clearer diagnostics when WorkMeter fails to launch.
- Added complete release metadata and version handling.

### Changed

- Improved release packaging for Intel and Apple Silicon Macs.
- Updated privacy documentation to describe local usage cache.

## v0.2.1

### Added

- Offline last-known usage display.
- Cache indicator when fresh data cannot be retrieved.
- Better diagnostics.

## v0.2.0

- First public preparation release.
