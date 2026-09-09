# Tessellate

A minimal native macOS menu-bar window manager. One hotkey, one command key,
window moved.

Tessellate replaces the small subset of a full window manager most people
actually use: put the focused window on the left, on the right, in the middle,
or fill the screen. It does that and nothing else.

The product principle: **hotkey → command → window moved.** Anything that makes
that path slower needs strong justification.

## How it works

Press the activation hotkey (**⌥Space** by default). Tessellate captures the
focused window and outlines it, so you can see what is about to move. Then press
a command key:

| Key     | Action      |
| ------- | ----------- |
| `←`     | Left        |
| `→`     | Right       |
| `Space` | Center      |
| `↑`     | Upper Half  |
| `↓`     | Lower Half  |
| `Tab`   | Maximize    |
| `Esc`   | Cancel      |

Placement mode expires after 2 seconds if you don't press anything, and a second
press of the activation hotkey cancels it.

Both the activation hotkey and all command keys are rebindable in Settings.
The activation hotkey may share a key with a command — ⌃Space to activate and
Space to center is a perfectly good setup.

## Requirements

- macOS 13 (Ventura) or later
- Accessibility permission

Tessellate needs Accessibility for two things: reading the focused window
through the Accessibility API, and a `CGEvent` tap to capture the command key.
Without it the activation hotkey still fires but nothing responds, so the app
asks for the permission on first launch and picks it up the moment you grant it
— no restart needed.

## Install

No notarized release yet. Build it yourself:

```sh
brew install xcodegen
xcodegen generate
open Tessellate.xcodeproj
```

Set your own `DEVELOPMENT_TEAM` in `project.yml`, then ⌘R.

### A note on signing

`project.yml` uses manual signing with an Apple Development identity rather than
ad-hoc signing. This is not incidental: macOS binds the Accessibility grant to
the code signature, so an ad-hoc signed build loses the permission on **every
rebuild**, and you end up re-granting it in System Settings all day. A stable
signing identity makes the grant persist.

Find your team ID with:

```sh
security find-identity -v -p codesigning
```

Note that the team ID is the one reported by `codesign -dv` on a signed
artifact, which is not the identifier shown in parentheses in the certificate
name.

### Downloadable releases

Push a tag that matches `CFBundleShortVersionString` (for example
`v0.3.0`) to run `.github/workflows/release.yml`. The workflow builds a
universal arm64/x86_64 app, signs it with Developer ID, notarizes it with
Apple, staples the ticket, and publishes a ZIP plus `SHA256SUMS` to the GitHub
Release.

The workflow requires these GitHub Actions secrets:

- `APPLE_TEAM_ID` — the Apple Developer team ID.
- `APPLE_DEVELOPER_CERTIFICATE_P12_BASE64` and `APPLE_DEVELOPER_CERTIFICATE_PASSWORD` — a base64-encoded Developer ID Application certificate and its export password.
- `APPLE_API_KEY_ID`, `APPLE_API_ISSUER_ID`, and `APPLE_API_PRIVATE_KEY_BASE64` — an App Store Connect API key and base64-encoded private `.p8` key for notarization.

Never commit the certificate, private API key, or their passwords. Keep them in
GitHub Actions secrets or an environment-specific secret manager.

## Configuration

Settings lives in the menu bar item.

**Commands** — choose a command once, then edit its shortcut and target zone
together. The shared map keeps the other zones outlined for reference, and the
activation shortcut lives at the top of the same section. Shortcuts are chosen
from native key and modifier menus, including Tab and the arrow keys.

The grid density and optional custom column/row counts sit directly below the
map because the grid is a snapping aid for editing, nothing more. Targets are
stored as fractions of the usable screen, so changing the grid changes only
where your edits snap; it never moves an existing target. By default the grid
size is derived from your display so cells come out roughly square, at a density
you choose (Light / Balanced / Dense), and it is recomputed when the display
configuration changes.

**General** — launch at login, show/hide the menu bar icon, and optionally sync
settings through iCloud. Sync uses Apple's iCloud Key-Value Store, keeps a local
copy as a fallback, and should be enabled on each Mac running Tessellate. It
syncs commands, shortcuts, zones, grid settings, and general preferences; it
does not sync Accessibility permission, which macOS grants per installation.
For production sync, enable the iCloud capability's Key-value storage service
for the App ID and use a provisioned distribution; Apple's KVS API is intended
for App Store or Mac App Store distribution.

**About** — whether Accessibility is granted, and the full path of the running
executable. The grant binds to one exact binary, and during development your
Xcode build and your command-line build are different files, so knowing which
one is asking saves a lot of confusion.

## Architecture

Roughly 2,100 lines of Swift, no dependencies.

| | |
| --- | --- |
| `Hotkeys/HotkeyManager` | Carbon `RegisterEventHotKey` for activation; a `CGEvent` tap, created once at launch and enabled only during placement mode, for command keys |
| `Window/WindowEngine` | Accessibility API: find the focused window, read and set its frame |
| `Window/ScreenGeometry` | Cocoa ↔ Accessibility coordinate conversion, and fraction → screen rect |
| `Overlay/FocusIndicator` | The outline around the window that is about to move |
| `Settings/*` | The settings window: one page — command editor, general, about |
| `Models/TessellateLayout` | Editable commands and grid; persisted to `UserDefaults` |
| `App/AppCoordinator` | Wires the above together |

Two decisions worth knowing about if you read the code:

**The target window is captured at activation, not at command time.** The
Accessibility calls that find the focused window are synchronous IPC to another
process and can be slow if that process is busy. Doing them when the activation
hotkey fires keeps them off the keypress path, and removes the race where the
frontmost window changes between your two keystrokes.

**Cocoa and Accessibility disagree about coordinates.** `NSScreen` uses a
bottom-left origin; the Accessibility API uses a global top-left origin. Every
rect crossing that boundary goes through `ScreenGeometry`, which is the only
place the conversion lives.

## Limitations

- One display. Each window is placed on the screen it is already on; there is no
  command to move a window to another display.
- Placement is not verified. Some apps clamp the frame they are given — Terminal
  snaps to character cells, others enforce a minimum size — and Tessellate does
  not currently read the frame back to check.
- No saved multi-window layouts, drag snapping, gaps, Spaces support,
  app-specific rules, or animations.

## Acknowledgments

Implementation patterns for Accessibility, focused-window discovery, global
hotkeys, and screen geometry are inspired by
[Rectangle](https://github.com/rxhanson/Rectangle) (MIT).

## License

MIT — see [LICENSE](LICENSE).
