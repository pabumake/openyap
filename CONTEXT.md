# OpenYap domain language

OpenYap has one product domain: turning a user's spoken dictation into text delivered to an intended text field. Platform APIs and process boundaries do not change this vocabulary.

## Core workflow

### Dictation session

A dictation session is one user-requested attempt to speak, prepare, and deliver text. It starts with an activation and ends as delivered, cancelled, discarded, or failed; it may wait between preparation and delivery.

### Active session

An active session is the one session currently capturing, processing, or attempting delivery on a device. Sessions awaiting delivery are dormant, so they do not block a new activation.

### Session identifier

A session identifier is the unique identity assigned at activation and carried by every later command, update, history entry, and delivery attempt. OpenYap never reuses it.

### Activation

An activation is a user's request to begin a dictation session. It can come from a shortcut, keyboard control, Action Button, Control Center, or the OpenYap app.

### Activation source

An activation source is the control that requested a session. It does not own the session and does not need to remain available after capture starts.

### Capture

Capture is the period in which OpenYap reads live microphone audio for a session. Use "capture" in the domain because OpenYap does not retain an audio recording by default.

### Capture host

The capture host is the trusted application process allowed to use the microphone and coordinate speech processing. On iOS this is the containing app, never the custom keyboard.

### Audio input selection

Audio input selection is the user's persistent microphone preference. Automatic selection prefers connected AirPods, then the built-in microphone, then the current system input or another available input. A manual selection identifies a Core Audio device by its stable UID and remains selected while disconnected.

### Stop

Stop ends capture and asks OpenYap to produce the best result from audio received so far. Stop differs from cancel because it preserves useful speech and continues toward delivery.

### Cancel

Cancel ends the session without preparing or delivering its captured speech. A cancelled session cannot be resumed or delivered.

### Discard

Discard removes a session's prepared text while it is awaiting delivery and ends the session. It differs from cancel because useful delivery text already exists.

## Text

### Volatile segment

A volatile segment is a provisional transcription for an audio range. It may change or disappear and must never be committed to history or delivery text.

### Final segment

A final segment is the transcriber's committed text for an audio range. Final segments form the raw transcript in audio order.

### Raw transcript

The raw transcript is the ordered text assembled from final segments before OpenYap applies its own cleanup, correction rules, or snippets. It is the source used for recovery and formatting retries.

### Smart formatting

Smart formatting removes clear filler and false starts, resolves explicit spoken corrections, and improves punctuation, capitalization, and layout without adding new meaning. If formatting cannot produce a safe result, the raw transcript remains usable.

### Delivery text

Delivery text is the exact text OpenYap intends to insert. It is derived from the raw transcript by optional smart formatting, followed by correction rules and snippet expansion.

### Formatted transcript

The formatted transcript is the immutable result of smart formatting before OpenYap applies custom terms, correction rules, or snippets. It separates model-driven cleanup from deterministic replacements.

### Initial delivery text

Initial delivery text is the immutable delivery text first prepared for a session. A history entry keeps it even when the user later edits the current text.

### Current text

Current text is the editable text a history entry will copy. It starts as the initial delivery text, and manual edits never change the raw transcript, formatted transcript, or initial delivery text.

### Custom term

A custom term is a user-authored spelling for a name, acronym, product, or specialist phrase. It may guide recognition where the speech engine permits and can be the canonical side of a correction rule.

### Correction rule

A correction rule maps a specific recognized form to a canonical form at token boundaries. It is deterministic and differs from a custom term that has no known incorrect form.

### Lexicon scope

A lexicon scope limits a custom term or correction rule to English, German, or any speech language. OpenYap applies the entry only when its scope matches the session's speech locale.

### Starter lexicon

The starter lexicon is the initial set of editable Apple ecosystem terms and common recognition corrections installed for a new user. OpenYap installs each starter version once; after installation, entries behave like custom terms and correction rules, so deletion or editing is not reversed.

### Applied replacement

An applied replacement records that a custom term or correction rule changed initial delivery text. It keeps the matched phrase, replacement, and occurrence count so later edits to the live word list cannot rewrite history.

### Snippet

A snippet maps a spoken trigger phrase to a literal saved expansion. OpenYap expands snippets after smart formatting so addresses, signatures, links, and code are not rewritten.

### Partial result

A partial result contains a valid raw transcript from only part of the intended capture because an interruption or speech-processing failure ended the input. It is marked partial and remains eligible for preparation and delivery.

## Delivery

### Insertion target

The insertion target is the text control that should receive delivery text. A target may disappear, reject third-party keyboards, become secure, or lose focus before delivery.

### Delivery agent

The delivery agent is the process currently able to write to the insertion target. The macOS app is its own delivery agent, while the iOS keyboard extension is distinct from the capture host.

### Delivery

Delivery is the act of placing delivery text into an insertion target. A successful transcription is not delivered until the target accepts the text.

### Delivery attempt

A delivery attempt is one try to deliver already prepared text. Retrying delivery never starts a new capture and never reruns smart formatting unless the user explicitly requests a formatting retry.

### Awaiting delivery

A session is awaiting delivery when delivery text exists but no insertion target has accepted it. This is a dormant recoverable state, not an active session or a failed dictation.

### Recovery copy

A recovery copy is delivery text exposed through local history or the pasteboard after automatic delivery cannot complete. It protects useful text without claiming that insertion succeeded.

## Persistence and support

### History entry

A history entry is the local record of a session that produced useful text. It retains the raw transcript, formatted transcript, initial delivery text, current text, locale, timing, partial-result marker, delivery outcome, and applied replacements, but not microphone audio.

### History retention

History retention is the period after which OpenYap deletes local history entries. The default is 30 days; the user can select 90 days or keep entries until deletion.

### Speech locale

A speech locale identifies the language and regional speech model used for one session, such as `en_US` or `de_DE`. It is more precise than the display language and must be supported by the current device.

### Speech asset

A speech asset is an operating-system-managed model required for a speech locale. A supported locale is not ready until its required asset is installed.

### Formatting availability

Formatting availability describes whether the on-device language model can accept a smart-formatting request now. It is independent of speech-asset availability and never blocks raw transcription delivery.

### Terminal outcome

A terminal outcome is delivered, cancelled, discarded, or failed. Awaiting delivery is nonterminal because the user or delivery agent can retry without speaking again.

### Failed session

A failed session has neither deliverable text nor remaining work that can produce it. Permission denial before capture and speech failure without a raw transcript are failures; formatting and insertion errors are not.

## Domain invariants

- A device has at most one active session, but several sessions may await delivery.
- Every command and update belongs to one session identifier.
- Volatile segments never enter the raw transcript.
- Delivery text never replaces the raw transcript.
- Manual edits change only current text.
- Word-list changes apply only to future preparations and never rewrite existing history.
- Starter lexicon entries become user-owned word-list entries after their one-time installation.
- Stop preserves usable speech; cancel discards it.
- A formatting failure falls back to the raw transcript.
- A delivery failure returns the session to awaiting delivery.
- A new activation does not discard or hide sessions awaiting delivery.
- Only a successful insertion produces the delivered outcome.
- Stale updates from another session cannot change the active session.
- OpenYap does not retain microphone audio unless a later, explicit product decision changes that policy.
- OpenYap resolves automatic audio input again when each capture starts.
- A disconnected manual input fails capture with a visible warning. OpenYap does not silently replace an explicit user choice.
