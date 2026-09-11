# iOS capture and keyboard feasibility prototype

> Throwaway prototype. Keep this out of production.

## Question

Can a containing iOS app keep a user-started microphone capture and Live Activity alive in the background while an OpenYap keyboard exchanges session-scoped commands and snapshots through an App Group, rejects stale commands, and inserts or recovers prepared text after the user returns to a host text field?

This prototype measures the public-API process split required by ADR 0002. It captures audio but does not transcribe it. Stop produces deterministic delivery text with the measured capture duration, which isolates capture lifetime, process communication, and delivery from speech-model behavior.

## Run

Connect and unlock the development iPhone, then run:

```sh
./run-on-device.sh
```

The script discovers the first connected iPhone with Developer Mode enabled. It generates an Xcode project, lets Xcode register the App Group and provisioning records, builds the app and its extensions, installs the app, and launches it.

## One-time keyboard setup

1. Open Settings > General > Keyboard > Keyboards > Add New Keyboard.
2. Add "OpenYap Prototype".
3. Enable Full Access so the keyboard can reach the App Group container.
4. Open Notes, Messages, Mail, or Safari and select the OpenYap keyboard.

## Guided checks

### Keyboard start, background capture, and insertion

1. In a host text field, select OpenYap Prototype and tap "Open app and start".
2. Grant microphone permission if asked. Confirm that the app shows `capturing` and the Live Activity appears.
3. Return to the host app. Confirm the keyboard shows the same session identifier and a rising buffer count.
4. Wait at least 30 seconds, then tap "Stop" on the keyboard.
5. Confirm the keyboard reaches `awaiting delivery`, then tap "Insert delivery text".
6. Confirm the known prototype text appears in the host field and the shared state becomes `delivered`.

### Stale command rejection

1. Start a capture and wait until the keyboard shows `capturing`.
2. Tap "Send stale stop".
3. Confirm capture continues and the stale rejection count increases.

### Keyboard disappearance and recovery

1. Start a capture, then switch away from the OpenYap keyboard.
2. Stop from the containing app or Live Activity after the keyboard heartbeat becomes stale.
3. Confirm the app reports that it copied a recovery copy.
4. Return to any text field and paste the captured result.

## Evidence to record

- App, keyboard, and Live Activity state at each process transition.
- Whether buffer count and elapsed capture time continue while the containing app is backgrounded.
- Whether the Live Activity remains visible for the full capture.
- Whether the keyboard receives matching snapshots and rejects a mismatched session identifier.
- Whether insertion succeeds after returning to the host field.
- Whether a stale keyboard heartbeat causes the containing app to create a recovery copy.
