# OpenYap roadmap

## Current release

Version 0.1.0 covers the local macOS dictation loop, cleanup, word list, snippets, history, statistics, microphone selection, global shortcut, menu-bar operation, and themes.

## Next

### App-specific formatting profiles

OpenYap already records the destination app for local statistics. The next feature should use that same app identity to select a formatting profile before text delivery.

The first pass should support a default profile plus optional profiles for individual bundle identifiers. Each profile can choose concise, neutral, or polished cleanup while preserving word-list and snippet behavior. OpenYap must show the selected profile in history so a rewrite remains explainable.

## Later

- Voice commands for editing selected text.
- A native iOS capture app and keyboard delivery prototype.
- Optional encrypted sync for word lists, snippets, and settings.
- Automatic update checks after signed GitHub releases exist.
