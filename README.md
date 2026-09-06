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

| Key     | Action   |
| ------- | -------- |
| `←`     | Left     |
| `→`     | Right    |
| `Space` | Center   |
| `↑`     | Maximize |
| `Esc`   | Cancel   |

Placement mode expires after 2 seconds if you don't press anything, and a second
press of the activation hotkey cancels it.

Both the activation hotkey and all four command keys are rebindable in Settings.
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

## Configuration

Settings lives in the menu bar item.

**Commands** — each of the four commands has a target region you edit on a grid,
plus its key binding.

**Grid** — the grid is a snapping aid for editing, nothing more. Targets are
stored as fractions of the usable screen, so changing the grid changes only
where your edits snap; it never moves an existing target. By default the grid
size is derived from your display so cells come out roughly square, at a density
you choose (Light / Balanced / Dense), and it is recomputed when the display
configuration changes. You can set explicit column and row counts instead.

**Permissions** — shows whether Accessibility is granted, and the full path of
the running executable. The grant binds to one exact binary, and during
development your Xcode build and your command-line build are different files, so
knowing which one is asking saves a lot of confusion.

## Architecture

Roughly 2,100 lines of Swift, no dependencies.

| | |
| --- | --- |
| `Hotkeys/HotkeyManager` | Carbon `RegisterEventHotKey` for activation; a `CGEvent` tap, created once at launch and enabled only during placement mode, for command keys |
| `Window/WindowEngine` | Accessibility API: find the focused window, read and set its frame |
| `Window/ScreenGeometry` | Cocoa ↔ Accessibility coordinate conversion, and fraction → screen rect |
| `Overlay/FocusIndicator` | The outline around the window that is about to move |
| `Models/TessellateLayout` | Targets, bindings, grid; persisted to `UserDefaults` |
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
  app-specific rules, animations, or sync. None of these are planned.

## Acknowledgments

Implementation patterns for Accessibility, focused-window discovery, global
hotkeys, and screen geometry are inspired by
[Rectangle](https://github.com/rxhanson/Rectangle) (MIT).

## License

MIT — see [LICENSE](LICENSE).
