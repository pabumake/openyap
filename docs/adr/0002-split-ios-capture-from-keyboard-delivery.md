# ADR 0002: Split iOS capture from keyboard delivery

Status: Accepted

Date: 2026-08-23

## Context

The desired iPhone interaction starts in a text field and ends with text in that field. Apple does not permit a custom keyboard extension to access the microphone. The containing app can capture audio and continue a user-started recording in the background, while the keyboard can insert text through its document proxy.

Pretending these are one process would hide the main iOS risk. The activation source, capture host, and delivery agent can appear and disappear independently.

## Decision

The containing iOS app owns microphone capture, speech processing, smart formatting, and the durable dictation session. The custom keyboard owns insertion into the current text target.

Both processes address the same session identifier. When the signing team permits App Groups, they share commands and snapshots through a versioned group container. A Live Activity remains active for the duration of background capture. Action Button, Control Center, keyboard, Live Activity, and in-app controls all act on the one active session.

If App Groups cannot be provisioned, the supported fallback is app capture followed by a recovery copy on the pasteboard. OpenYap will not use private APIs to imitate direct keyboard recording.

## Consequences

- Starting from the keyboard may open the containing app and require the user to return to the previous app.
- The keyboard can disappear before delivery. Delivery text must remain awaiting delivery instead of being discarded.
- Several sessions may await delivery while a newer session becomes active, so no shared value can mean "the current transcript."
- Commands and snapshots need session identifiers, idempotency, atomic replacement, and stale-update rejection.
- Full Access and App Group onboarding become part of the intended keyboard experience.
- Secure fields and apps that reject third-party keyboards cannot receive automatic delivery.
- Physical iPhone verification is a release gate because simulator success cannot prove process lifetime or keyboard behavior.

## Alternatives considered

### Record directly in the keyboard

Apple explicitly prohibits microphone access in custom keyboard extensions. This is not a viable public-API design.

### App-only capture with manual paste

This works with fewer capabilities and remains the fallback. It does not meet the desired system-wide keyboard interaction.

### Send audio to a server from the keyboard

The keyboard still cannot capture microphone audio. It would also violate the on-device processing decision.

### Use private APIs or accessibility automation

This would be brittle, unsafe to distribute, and unnecessary for the personal-device v1.

## Revisit when

Revisit this split if Apple grants microphone capture to keyboard extensions, adds a system dictation extension point, or prevents the containing app from sustaining the documented background recording flow. Any replacement must preserve recoverable delivery text and the one-active-session invariant.
