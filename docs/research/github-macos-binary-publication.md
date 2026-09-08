# Publishing OpenYap macOS binaries on GitHub

This document records the unsigned 0.1.0 release decision. [macOS updates and cross-platform options](macos-updates-and-cross-platform-options.md) supersedes it for updater-enabled releases.

## Question and constraints

How should OpenYap publish a downloadable macOS 26 binary from GitHub while the project has no Apple signing identity?

The current release is version 0.1.0. It targets Apple silicon, uses Xcode 26, and is distributed outside the Mac App Store. The first binary is intentionally an unsigned experimental prerelease. No private signing material may enter the repository.

## Established facts

- GitHub Releases can attach compiled binaries to a Git tag. GitHub also supplies automatic source archives, which are different from the packaged application download. See [About releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases).
- GitHub's `macos-26` hosted runner is available on arm64 and includes Xcode 26.6. See [Choosing the runner for a job](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job) and the [macOS 26 runner image](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md).
- A trusted app distributed outside the Mac App Store needs a Developer ID Application certificate. See [Developer ID certificates](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/).
- Apple's normal notarization path requires a Developer ID signature, hardened runtime, a secure timestamp, and a valid code signature. See [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) and [Preparing your app for distribution](https://developer.apple.com/documentation/Xcode/preparing-your-app-for-distribution).
- GitHub Actions secrets can store encoded certificate data, but Base64 encoding is not encryption. See [Using secrets in GitHub Actions](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets).

## Local verification

An unsigned Release archive built successfully with Xcode 26.6. Forcing `ARCHS=arm64` produced a single-architecture application. Copying the app, clearing extended attributes, applying an ad hoc bundle signature, and packaging it with `ditto` produced a 4.8 MB ZIP. Bundle metadata reported identifier `dev.pabu.openyap`, version `0.1.0`, build `1`, and minimum macOS version `26.0`.

The Mac has no valid code-signing identities. The current build can therefore be tested and shared as an unsigned prerelease, but it cannot pass the trusted Developer ID and notarization path.

## Decision

Publish `v0.1.0` as a GitHub prerelease containing an arm64 app ZIP and a SHA-256 checksum. Build from the exact tagged tree, run tests first, apply an ad hoc signature to seal the complete bundle, and label the download as unsigned. Keep the existing public tag unchanged.

Use a GitHub-hosted `macos-26` runner and the repository's temporary workflow token. Do not configure certificate or notarization secrets for this release.

## Later signed release

Before describing a release as trusted, enroll in the Apple Developer Program and create a Developer ID Application certificate. Then enable and test hardened runtime, sign with a secure timestamp, submit the package with `notarytool`, staple the ticket, and verify the result with `codesign`, `spctl`, and `stapler`.

The unresolved item is the Apple team identity. Verify it by installing the Developer ID certificate and checking `security find-identity -v -p codesigning` before implementing the signed workflow.
