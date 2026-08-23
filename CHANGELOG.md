# Changelog

OpenYap follows semantic versioning. GitHub publishes this file from the `main` branch, and the app keeps a bundled copy for offline use.

## 0.1.0 - 2026-08-24

### Added

- Native macOS dictation with Apple's on-device speech recognition.
- Local smart cleanup, word list corrections, and snippets.
- Editable transcription history with word, character, duration, and WPM details.
- Local usage statistics with streaks, correction counts, and destination-app totals.
- Configurable global shortcut, microphone selection, launch-at-login, menu-bar mode, and Catppuccin themes.
- In-app version information and a GitHub-backed changelog with an offline fallback.

### Fixed

- Automatic microphone selection now falls back from disconnected AirPods to the built-in microphone.
- The floating dictation overlay no longer paints opaque rectangles outside its rounded corners.
