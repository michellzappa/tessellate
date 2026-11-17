# Changelog

Every entry below is a `v`-prefixed git tag. Add an entry here before you cut
a tag. The app bundles this file for HouseKit (`Changelog.load`).

## 0.4.1 - Unreleased

### Fixed

- The idle event tap no longer loops and uses CPU.

## 0.4.0 - 2026-09-14

### Changed

- Tessellate joins the house apps: HouseKit, the shared AppKit settings
  window, Swift 6 and macOS 14.
- The menu bar icon uses the shared menu bar plate with procedural panes.
- The shortcut recorder and the activation hotkey come from HouseKit.
  Accessibility trust checks use HouseKit too.

### Fixed

- Tessellate picks the focused Chrome window correctly.

## 0.3.2 - 2026-09-09

- Maintenance release.

## 0.3.0 - 2026-09-08

- First signed release.
- Commands are editable, with names you can turn on per command.
- One editor for command shortcuts and zones.
- Shortcut capture stays active through focus changes and records each
  shortcut in one step.
- Placement targets are stored as screen fractions, not grid cells.
- A neutral focus indicator and a new app icon.

### Fixed

- The activation hotkey fires.
- Accessibility polling works in release builds.
- SwiftUI view-update warnings.
