# OpenYap

OpenYap is a local macOS 26 dictation app. It uses Apple's on-device `SpeechAnalyzer` for transcription and Foundation Models for optional transcript cleanup. It does not retain microphone audio.

The Mac app keeps local text history for 30 days by default. History shows smart-cleanup, word-list, snippet, and manual-edit changes separately. You can edit and copy saved text, inspect word and character counts, add language-scoped vocabulary terms or exact correction rules, and expand spoken snippet triggers into saved text.

The Statistics tab tracks dictated words and characters, weighted WPM, capture time, estimated time saved, cleanup activity, streaks, and destination-app usage. OpenYap stores these as local numeric aggregates without transcript text or audio. Statistics remain after history retention removes a transcript and have their own reset control in Settings.

The sidebar shows the installed version. About contains the full build number and renders release notes from the repository's `CHANGELOG.md`. If GitHub cannot be reached, the app shows the copy bundled with that build.

## Requirements

- macOS 26 on Apple silicon
- Xcode 26
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) when regenerating the project

The checked-in Xcode project can be opened without running XcodeGen.

## Planning

Start with the [roadmap](ROADMAP.md) for portfolio order and links to active planning maps.

## Run locally

Generate and open the Xcode project:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodegen generate
open OpenYap.xcodeproj
```

Or build, install, sign, and launch the app in one command:

```sh
./scripts/build-and-install-mac.sh
```

## Download the macOS app

The `v0.2.0` GitHub prerelease provides `OpenYap-0.2.0-macOS-arm64.zip` and a SHA-256 checksum. This build requires macOS 26 on Apple silicon.

The app is signed with Developer ID and notarized by Apple. Download it from the [OpenYap website](https://pabumake.github.io/openyap/), verify the checksum, extract it, and move `OpenYap.app` to `/Applications`.

To verify the downloaded ZIP and checksum in the same directory:

```sh
shasum -a 256 -c OpenYap-0.2.0-macOS-arm64.zip.sha256
```

Version 0.1.0 has no updater, so install version 0.2.0 manually. Version 0.2.0 and later builds check the signed GitHub feed once each day. OpenYap asks before it downloads, installs, or relaunches. You can disable scheduled checks in Settings and start a manual check from About, Settings, or the menu bar.

## Build a tagged release locally

The release packager exports the exact tagged source and runs the tests. It then creates a Developer ID signed arm64 archive, submits it to Apple for notarization, staples the ticket, verifies it with Gatekeeper, and writes a ZIP, checksum, release notes, and signed Sparkle appcast under `.build/releases/`:

```sh
./scripts/package-release-mac.sh v0.2.0
```

Pass a second argument to choose another output directory. The script refuses to replace an existing release asset.

The packager needs these environment variables:

- `OPENYAP_DEVELOPMENT_TEAM`: Apple Team ID.
- `OPENYAP_NOTARY_KEY_ID`: App Store Connect API key ID.
- `OPENYAP_NOTARY_ISSUER_ID`: App Store Connect issuer ID.
- `OPENYAP_NOTARY_KEY_PATH`: path to the API key `.p8` file.
- `OPENYAP_DEVELOPER_ID_IDENTITY`: optional certificate name. The default is `Developer ID Application`.
- `OPENYAP_SPARKLE_PRIVATE_KEY`: optional exported Sparkle key. Local builds use the `dev.pabu.openyap` login Keychain entry when this variable is absent.

The release workflow expects these GitHub Actions secrets:

- `APPLE_TEAM_ID`
- `DEVELOPER_ID_P12_BASE64`
- `DEVELOPER_ID_P12_PASSWORD`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_PRIVATE_KEY`
- `SPARKLE_PRIVATE_KEY`

Sparkle stored the private update key in the login Keychain under account `dev.pabu.openyap`. Export it with Sparkle's `generate_keys --account dev.pabu.openyap -x <private-key-file>` command, save that file in `SPARKLE_PRIVATE_KEY`, and remove the export after the secret is set. Keep a separate protected backup. The public key is safe to commit and is already in the generated app configuration.

Configure GitHub Pages to use GitHub Actions before the first signed release. A `vMAJOR.MINOR.PATCH` tag starts the release workflow. After that workflow succeeds, a separate workflow on `main` publishes `appcast.xml` at `https://pabumake.github.io/openyap/appcast.xml`. The release stops if any signing, notarization, Sparkle signing, or Gatekeeper check fails.

The development installer resets OpenYap's Microphone, Input Monitoring, and Accessibility grants so a newly signed build follows the permission flow again. Set `OPENYAP_KEEP_PERMISSIONS=1` when you need to rebuild without resetting them.

Choose the `OpenYap` scheme and click Run. Xcode may ask you to select a signing team. Install the successful build at `/Applications/OpenYap.app` before granting permissions. This keeps the app path stable across rebuilds.

On first use, allow Microphone and Input Monitoring access. Right Option starts and stops dictation by default. Use the shortcut recorder in the app to replace it. Grant Accessibility access if you want OpenYap to paste into the app that was active when capture started.

The microphone setting defaults to Automatic. OpenYap checks available inputs when each capture starts and prefers connected AirPods, then the built-in microphone. You can select a specific input in Settings. If that device disconnects, OpenYap keeps the selection and shows a warning instead of recording from a different microphone.

On the first launch, OpenYap asks whether it should start at login. Settings can also make later launches menu-bar-only, with no main window or Dock icon. The menu bar includes an Open OpenYap command. Appearance includes System plus the Catppuccin Latte, Frappé, Macchiato, and Mocha palettes. Minimize-on-record, launch-at-login, microphone, and shortcut controls remain available in Settings. A starter word list includes OpenYap and common Apple product names and can be edited or deleted like any other entry.

Snippets match spoken triggers at whole-word boundaries anywhere in a new dictation. Matching ignores capitalization and prefers longer triggers when phrases overlap. OpenYap applies snippets after smart cleanup and word-list corrections, then inserts the saved expansion without processing it again.

English speech assets may already be installed. Selecting German can trigger a one-time operating-system model download.

## Test

Run the macOS unit tests without code signing:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test \
  -project OpenYap.xcodeproj \
  -scheme OpenYap \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

## Privacy and permissions

OpenYap processes speech and transcript cleanup on the device. It stores transcript history, dictionary entries, snippets, settings, and numeric usage statistics locally. It does not retain microphone audio.

Microphone permission is required for capture. Input Monitoring enables the global shortcut. Accessibility enables automatic paste into the previously active application. The development build runs without App Sandbox because global shortcut monitoring and cross-application paste need system integration that a sandboxed build does not provide.

Please report security problems through the process in [SECURITY.md](SECURITY.md), not through a public issue.

## License

OpenYap is available under the [MIT License](LICENSE).
