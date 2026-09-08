# macOS updates and cross-platform options

Date: 2026-09-08

## Question

Can OpenYap update itself from GitHub without an Apple Developer Program membership? Would a Rust or Tauri rewrite improve macOS distribution, Windows and Linux support, or the planned iOS app?

## Established facts

- Sparkle can read an HTTPS appcast and verify update archives with EdDSA. It can also sign the feed and release notes. The private EdDSA key stays outside the app. See [Sparkle setup](https://sparkle-project.org/documentation/) and [Publishing an update](https://sparkle-project.org/documentation/publishing/).
- Sparkle recommends Developer ID signing and notarization for public macOS releases. Its default schedule checks once every 24 hours. See [Sparkle setup](https://sparkle-project.org/documentation/).
- Apple requires an Apple Developer Program membership for Developer ID and notarization. The membership costs 99 USD per year, or the local equivalent. See [Choosing a membership](https://developer.apple.com/support/compare-memberships/) and [Program enrollment](https://developer.apple.com/help/account/membership/program-enrollment).
- Apple requires a Developer ID Application signature, hardened runtime, and secure timestamp for the normal notarization path. See [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).
- A free Apple account supports local development. It does not provide trusted public Mac distribution. See [Choosing a membership](https://developer.apple.com/support/compare-memberships/).
- Tauri still needs Apple signing and notarization for a trusted macOS download. Its free-account path remains unverified in Gatekeeper. See [Tauri macOS code signing](https://v2.tauri.app/distribute/sign/macos/).
- The Sparkle advisory [GHSA-3x7w-j75x-ppq5](https://github.com/sparkle-project/Sparkle/security/advisories/GHSA-3x7w-j75x-ppq5) affects versions through 2.9.5. Version 2.9.6 contains the fix.
- `swift-markdown` parses Markdown into a semantic tree. This lets a SwiftUI view keep headings, lists, quotes, code blocks, tables, and inline formatting. See the [swift-markdown repository](https://github.com/swiftlang/swift-markdown).

## Local findings

The former About view converted the full file to one `AttributedString` and placed it in one SwiftUI `Text`. That path preserved some inline styles but did not preserve the document's block layout. A semantic block renderer fixes the visible problem without a web view or executable HTML.

OpenYap currently depends on Apple-only APIs for speech analysis, local language models, SwiftData, global keyboard monitoring, accessibility insertion, and Core Audio. A Tauri shell would need Swift plug-ins or separate native implementations for most of this behavior. It would not turn the current app into a portable application.

The iOS design also depends on SwiftUI, Speech, App Groups, Live Activities, and a keyboard extension. Replacing the Mac app with Tauri would create two client stacks and would not remove the native iOS work.

## Decision

Keep the macOS app in Swift. Use Sparkle 2.9.6 for GitHub-hosted updates. Check once each day. Ask the user before download, installation, and relaunch. Sign update archives and the appcast with the dedicated Sparkle key.

Use Developer ID signing and Apple notarization for every updater-enabled public build. Enroll in the Apple Developer Program before publishing that build. The same membership also supports the planned TestFlight and App Store work for iOS.

The first updater-enabled build needs a manual installation because version 0.1.0 has no updater. Later signed builds can update through Sparkle.

## Options without paid membership

Two technical options remain available, but neither gives users the normal trusted install flow:

1. Publish an ad hoc signed ZIP. Users must approve the app in macOS security settings. OpenYap can verify later Sparkle archives with EdDSA, but Gatekeeper still cannot verify the publisher.
2. Ask users to build from source. This is suitable for contributors and personal use. It is not a normal product release.

A Tauri or Rust rewrite has the same Apple membership limit. It adds migration work before it adds Windows or Linux support.

## Cross-platform path

Keep the domain rules and transcript transformations in small platform-neutral Swift types where practical. Build the iOS app from the native Apple codebase. If Windows or Linux demand becomes real, first define a portable core boundary and prototype one non-Apple speech and insertion adapter. Choose its language and UI toolkit from that evidence.

## Release prerequisites

- Active Apple Developer Program membership.
- Developer ID Application certificate exported to CI as a password-protected PKCS#12 file.
- App Store Connect API key for `notarytool`.
- Sparkle private key exported from the `dev.pabu.openyap` Keychain account and stored as a GitHub Actions secret.
- GitHub Pages configured to deploy with GitHub Actions.

The repository contains the build, signing, notarization, appcast, and Pages workflows. A signed release requires these account-owned credentials in GitHub Actions.
