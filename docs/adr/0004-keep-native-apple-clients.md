# ADR 0004: Keep native Apple clients

Status: Accepted

Date: 2026-09-08

## Context

OpenYap needs trusted macOS updates, and it may later support Windows and Linux. A Rust or Tauri rewrite could provide a shared desktop shell. The current Mac app uses Apple speech analysis, Foundation Models, SwiftData, Core Audio, accessibility insertion, and global keyboard events. The planned iOS app also needs native app, keyboard extension, App Group, and Live Activity code.

Changing the desktop toolkit does not change Apple's signing rules. A Tauri Mac app still needs Developer ID signing and notarization for normal public distribution.

## Decision

Keep macOS and iOS as native Swift applications. Add Sparkle to the Mac app for signed GitHub updates. Use one Apple Developer Program membership for Developer ID distribution and the later iOS release path.

OpenYap accepts update metadata and archives only over HTTPS. An update is installable only after Sparkle verifies the signed appcast, release information, archive EdDSA signature, bundle signature, version, and system requirements. Public updater-enabled Mac builds use Developer ID signing and Apple notarization; a GitHub asset alone is not a trusted release. Scheduled checks do not send a system profile, and the user approves each download, installation, and relaunch.

Keep durable domain rules separate from platform adapters. Do not start a shared Rust core until a Windows or Linux prototype proves that two supported clients need the same non-UI implementation.

## Consequences

- The Mac app keeps direct access to the Apple APIs it already uses.
- The iOS plan can reuse Swift domain types and Apple-platform knowledge.
- Windows and Linux remain separate product efforts. They need speech, model, shortcut, insertion, persistence, packaging, and update adapters.
- A future portable core can still use Rust. It must expose a small versioned interface and must not own Apple UI or extension lifecycles.
- Apple Developer Program membership remains a release requirement for trusted Mac downloads and iOS distribution.

## Alternatives considered

### Rewrite the full desktop app with Tauri

This could share a web UI across desktop systems. The current Apple services would still need native bridges. It would add a second UI stack and would not reduce the iOS work.

### Move the domain core to Rust now

This could prepare a shared library. There is no Windows or Linux adapter yet to define the correct boundary. A premature core would encode guesses and add Swift foreign-function work.

### Keep publishing unverified Mac builds

This avoids the annual program fee. Gatekeeper cannot verify the publisher, and the update flow cannot provide the intended trust level.

## Revisit when

Revisit the portable core after a tested Windows or Linux prototype exists and at least two clients need the same domain implementation. Compare the cost of a Rust library, separate native implementations, and another shared runtime with measured adapter complexity.
