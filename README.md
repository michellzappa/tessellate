# Tessellate

A minimal native macOS menu-bar window manager. Replaces the small subset of
[Moom](https://manytricks.com/moom/) you actually use:

- global activation hotkey (⌥ Space by default)
- move the focused window to left, right, center, or maximize
- configure target positions on a 16×10 grid, per command
- runs entirely from the menu bar

Built for speed. The product principle: **hotkey → command → window moved.**
Anything that makes that path slower needs strong justification.

## Requirements

- macOS 13 (Ventura) or later
- Accessibility permission (System Settings → Privacy & Security → Accessibility)

## Build

```sh
brew install xcodegen   # if not installed
xcodegen generate
open Tessellate.xcodeproj
```

In Xcode: set your `DEVELOPMENT_TEAM` under Signing & Capabilities, then ⌘R.
The first launch will trigger the Accessibility prompt.

## Hotkey

Default activation: **⌥ Space**. May conflict with Spotlight — either change
Spotlight's shortcut in System Settings → Keyboard → Keyboard Shortcuts →
Spotlight, or change Tessellate's in Settings → Activation.

After activation, press a configured command key:

| Key   | Action   |
| ----- | -------- |
| ←     | Left     |
| →     | Right    |
| Space | Center   |
| ↑     | Maximize |
| Esc   | Cancel   |

All four command keys are rebindable in Settings → Commands.

Placement mode expires automatically after 2 seconds if no command key is
pressed.

## Out of scope (v1)

Multi-window saved layouts, multiple monitors, title-bar hover controls, drag
snapping, gaps, Spaces, app-specific rules, animations, sync, accounts.

## License

MIT — see [LICENSE](LICENSE).

## Acknowledgments

Implementation patterns (Accessibility, focused-window discovery, global
hotkeys, screen geometry) inspired by
[Rectangle](https://github.com/rxhanson/Rectangle) (MIT).
