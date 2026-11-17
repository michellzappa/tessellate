# Working on Tessellate

Tessellate is a menu bar window manager for macOS. AppKit, Swift 6,
macOS 14, bundle id `app.tessellate.Tessellate`.

## Build

XcodeGen owns the project. Edit `project.yml`, then run `xcodegen generate`.
`Tessellate.xcodeproj` is not in git. Never hand-edit it.

- `./scripts/build-app.sh` regenerates the project and the icon, builds
  Release, signs with the stable Apple Development identity and installs to
  `/Applications/Tessellate.app`. `--debug` builds Debug. This is for mz's Mac.
- The green gate is the CI build (`.github/workflows/build.yml`):

```bash
xcodegen generate && xcodebuild build -project Tessellate.xcodeproj -scheme Tessellate -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO -quiet
```

Run it on mz-mini with `remote-build '<command>'` from inside the clone. Do
not build Swift on the laptop.

## Shared package

HouseKit (`michellzappa/housekit`) supplies the menu bar plate, the app icon,
the status menu tail, the settings window, launch at login and the changelog
parser. `project.yml` pins a HouseKit release tag by URL (`exactVersion`), so
CI, mz-mini and the laptop build the same code.

- To change HouseKit: merge in its repo, tag a new release, then move the pin
  here on purpose. Never go back to `path: ../housekit`.
- `scripts/build-app.sh` builds `housekit-icon` from the resolved package
  checkout in `build/DerivedData`. Set `HOUSEKIT_PATH` to try a local
  HouseKit clone.

## Release

`.github/workflows/release.yml` runs on a `v*` tag. The tag must match
`CFBundleShortVersionString` in `Tessellate/Resources/Info.plist`. The workflow archives a
universal app, signs it with Developer ID, notarizes, staples and publishes a
zip plus `SHA256SUMS` to GitHub Releases.

- Add a `CHANGELOG.md` entry `## X.Y.Z - YYYY-MM-DD` before you tag. The app
  bundles the file for HouseKit's About pane.
- The workflow needs six secrets: `APPLE_TEAM_ID`,
  `APPLE_DEVELOPER_CERTIFICATE_P12_BASE64`, `APPLE_DEVELOPER_CERTIFICATE_PASSWORD`,
  `APPLE_API_KEY_ID`, `APPLE_API_ISSUER_ID`, `APPLE_API_PRIVATE_KEY_BASE64`.

## Traps

- Release runs fail since v0.3.2: the archive step needs a provisioning
  profile with the iCloud feature (the iCloud key-value entitlement), and the
  workflow has none. The last published release is 0.3.0.
- Local builds strip the iCloud key-value entitlement before signing.
  launchd refuses to start an unprovisioned app that claims it. iCloud sync
  works only in a provisioned release build.
- TCC keys the Accessibility grant to the code signature. Sign local builds
  with the stable Apple Development identity (`build-app.sh` does this).
- The team ID that `codesign -dv` reports is the one to use. It is not the
  identifier in parentheses in the certificate name.
- The event tap must not spin when idle (fixed in 0.4.1). Check CPU use
  after you change `Hotkeys/HotkeyManager.swift`.
- Settings still uses the deprecated AppKit `SettingsWindowController` and
  `AboutPage`. They do not show the changelog.

## Writing

Docs, comments and commit messages use Simplified Technical English: active
voice, short sentences, one word for one thing. No em dashes in UI copy.
