# ADR 0001: Process dictation on device

Status: Accepted

Date: 2026-08-23

## Context

Wispr Flow sends dictation to a network service. OpenYap targets an Apple silicon Mac and iPhone 15 Pro Max running version 26 of Apple's operating systems. Both devices can use Apple's on-device speech and language models.

The product promise is private, offline dictation. A server fallback would make connectivity, accounts, remote retention, vendor selection, and service operation part of the core product.

## Decision

OpenYap will transcribe and format dictation on the device. It will store user-authored terms, snippets, settings, and text history locally. It will not retain microphone audio by default.

A missing speech asset may require a one-time Apple-managed download. After installation, losing network access must not block capture, transcription, formatting fallback, or delivery.

## Consequences

- Dictation content does not need an OpenYap backend.
- The app needs no account system for v1.
- Available locales and formatting depend on the device, installed assets, region, and Apple Intelligence settings.
- Smart formatting can be unavailable even when transcription works. Raw transcript delivery must remain independent.
- Cross-device sync, organization policy, and server-grade model quality are outside v1.
- Local history needs clear deletion and retention controls before broader distribution.

## Alternatives considered

### Cloud transcription and formatting

This could support more models and centralize updates. It contradicts the offline requirement and adds operational and privacy work before the core interaction is proven.

### Local speech with optional cloud formatting

This keeps capture offline but makes wording quality depend on connectivity and a second privacy policy. The on-device Foundation Model is good enough to test the product without that split.

### User-selectable local or cloud processing

This adds settings, divergent failure modes, and a backend contract. There is no evidence yet that the local path needs replacement.

## Revisit when

Reconsider this decision only if measured on-device speech accuracy or formatting quality fails the accepted English and German fixture set, or if a required locale has no Apple-managed on-device path. A revisit must include retention, encryption, deletion, offline behavior, cost, and failure-mode evidence.
