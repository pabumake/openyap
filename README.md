# OpenYap

OpenYap is a local macOS 26 dictation app. It uses Apple's on-device `SpeechAnalyzer` for transcription and Foundation Models for optional transcript cleanup. It does not retain microphone audio.

The Mac app keeps local text history for 30 days by default. History shows smart-cleanup, word-list, snippet, and manual-edit changes separately. You can edit and copy saved text, inspect word and character counts, add language-scoped vocabulary terms or exact correction rules, and expand spoken snippet triggers into saved text.

The Statistics tab tracks dictated words and characters, weighted WPM, capture time, estimated time saved, cleanup activity, streaks, and destination-app usage. OpenYap stores these as local numeric aggregates without transcript text or audio. Statistics remain after history retention removes a transcript and have their own reset control in Settings.

The sidebar shows the installed version. About contains the full build number and reads release notes from the repository's `CHANGELOG.md`. If GitHub cannot be reached, the app shows the copy bundled with that build.

## Requirements

- macOS 26 on Apple silicon
- Xcode 26
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) when regenerating the project

The checked-in Xcode project can be opened without running XcodeGen.

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
