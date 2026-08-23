# Dictation lifecycle

This document tests the vocabulary in [CONTEXT.md](../../CONTEXT.md) against concrete behavior. It describes product rules, not platform APIs.

## State model

```text
requested -> preparing -> capturing -> finalizing -> preparing text -> awaiting delivery
awaiting delivery -> delivering -> delivered
delivering -> awaiting delivery on rejection
awaiting delivery -> discarded
any pre-delivery active state -> cancelled
any state without usable text -> failed
finalizing with partial text -> preparing text, marked partial
formatting error -> awaiting delivery with raw transcript
```

`Preparing text` includes optional smart formatting, correction rules, and snippet expansion. It does not mean microphone preparation.

Awaiting-delivery sessions are dormant. A device may retain several of them, but only one session can capture, process, or attempt delivery at a time.

## Command rules

| Device condition | Start | Stop | Cancel | Retry delivery |
| --- | --- | --- | --- | --- |
| No active session and no awaiting-delivery session | Create a requested session | Ignore | Ignore | Reject |
| No active session with awaiting-delivery sessions | Create a requested session and retain every waiting session | Ignore | Ignore | Deliver the selected waiting session |
| Requested or preparing | Return the same session for a duplicate activation; reject another activation | Treat as cancel because no capture exists | Cancel | Reject |
| Capturing | Return the same session for a duplicate activation; reject another activation | Finalize once | Cancel | Reject |
| Finalizing or preparing text | Return the existing session for a duplicate activation; reject another activation | Ignore duplicate stop | Cancel remaining work | Reject |
| Delivering | Return the existing session for a duplicate activation; reject another activation | Ignore | Do not interrupt an insertion already handed to the target | Ignore duplicate retry |

A duplicate activation has the same session identifier or idempotency token. A different activation while a session is active is a conflict, even if it came from another control.

## Scenarios

### Mac hold-to-talk succeeds

1. The hotkey creates a requested session and becomes its activation source.
2. Permission and speech assets pass preparation.
3. Key-down begins capture. Key-up stops it.
4. Final segments form the raw transcript.
5. OpenYap prepares delivery text and attempts insertion into the focused target.
6. The target accepts it. The session becomes delivered and its history entry records that outcome.

### iPhone changes process ownership

1. The keyboard activates a session but cannot capture audio.
2. The containing app becomes capture host and starts capture.
3. The user returns to the host app. The keyboard becomes delivery agent again.
4. Stop can come from the keyboard, Action Button, Control Center, Live Activity, or containing app. All controls address the same active session.
5. The containing app prepares delivery text. The keyboard delivers only a matching session result.

The activation source, capture host, and delivery agent are roles. No role change creates a second session.

### Formatting is unavailable

The session completes transcription and has a raw transcript. Formatting availability is false, so OpenYap skips smart formatting, applies deterministic rules and snippets, and proceeds to awaiting delivery. The session does not fail.

### Insertion target disappears

OpenYap has delivery text, but the original target no longer exists. The delivery attempt fails and the session returns to awaiting delivery. The text remains in local history and, where permitted, as a recovery copy on the pasteboard.

### Capture is interrupted after useful speech

An audio interruption ends capture after at least one final segment exists. OpenYap finalizes what it can, marks the result partial, and prepares it for delivery. The user sees that the result is incomplete before accepting or discarding it.

### Capture fails before useful speech

Microphone permission is denied, the speech asset cannot install, or capture ends before any final segment exists. The session becomes failed because there is no deliverable text. Retry creates a new session after the blocking condition changes.

### User cancels during finalization

Cancel discards volatile and final segments for that session and prevents delivery. A late speech or formatting update carries the cancelled session identifier and must not revive it.

### Stop arrives twice

The first Stop closes capture and begins finalization. Later Stop commands for the same session do nothing. They cannot create duplicate finalization, history entries, or delivery attempts.

### A stale iOS update arrives

The keyboard receives a snapshot for an older session after a newer one is active. It ignores the snapshot because session identifiers differ. Text from two sessions is never combined.

### Delivery is retried

The user selects an awaiting-delivery history entry and retries in a new insertion target. OpenYap reuses its existing delivery text. The retry does not capture audio, transcribe again, or silently change wording.

### A history entry is edited

The user changes current text in history. OpenYap saves the edit after a short pause and uses it for later copy actions. The raw transcript, formatted transcript, initial delivery text, and saved replacement evidence remain unchanged. Revert restores current text from initial delivery text without rerunning preparation.

### A correction rule changes

The user edits or deletes a correction rule after it has changed a transcript. Existing history keeps its initial delivery text and applied-replacement evidence. The new rule applies only when OpenYap prepares a later session.

### The user activates while another session awaits delivery

OpenYap creates a new session and leaves the prior result awaiting delivery in history. The new session becomes active, but it cannot overwrite, auto-deliver, or hide the older result.

### The user discards an awaiting-delivery session

Discard deletes the prepared result and ends that session as discarded. A late delivery-agent update for its session identifier cannot restore or insert the discarded text.

## Acceptance rules

- Every visible state maps to exactly one domain state.
- The user can distinguish listening, processing, awaiting delivery, delivered, cancelled, and failed.
- Any text presented as delivered was accepted by an insertion target.
- Useful partial text survives interruption and carries a partial marker.
- Retrying delivery is safe and does not alter the prepared wording.
- A process restart can recover every awaiting-delivery session without reviving capture.
