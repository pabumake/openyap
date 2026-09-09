# OpenYap domain language

OpenYap turns a user's spoken dictation into text for an intended text field. This glossary defines the product language shared by every client.

## Sessions

**Dictation session**:
One user-requested attempt to capture speech, prepare text, and deliver it. A session may wait after text preparation until delivery becomes possible.

**Active session**:
The session currently capturing, processing, or attempting delivery. A session awaiting delivery is dormant rather than active.

**Session identifier**:
The unique identity of a dictation session across its commands, updates, history entry, and delivery attempts.

**Activation**:
A user's request to begin a dictation session.

**Activation source**:
The control that requests a dictation session.

**Capture**:
The period when OpenYap reads live microphone audio for a dictation session.
_Avoid_: Recording

**Capture host**:
The application process that captures microphone audio and coordinates speech processing.

**Audio input selection**:
The user's preference for automatic or manual microphone choice.

**Stop**:
The command that ends capture and continues the session with the useful speech collected so far.

**Cancel**:
The command that ends a session without preparing or delivering its captured speech.

**Discard**:
The command that ends an awaiting-delivery session and removes its prepared text.

**Terminal outcome**:
The final state of a session: delivered, cancelled, discarded, or failed.

**Failed session**:
A session with no deliverable text and no remaining work that can produce it.

## Text preparation

**Volatile segment**:
A provisional transcription for an audio range that may change or disappear.

**Final segment**:
Committed transcription for an audio range.

**Raw transcript**:
The ordered text assembled from final segments before OpenYap applies cleanup, correction rules, or snippets.

**Smart formatting**:
Meaning-preserving cleanup of a raw transcript, including filler removal, spoken corrections, punctuation, capitalization, and layout.

**Formatted transcript**:
The result of smart formatting before deterministic replacements and snippet expansion.

**Delivery text**:
The exact prepared text that OpenYap intends to insert.

**Initial delivery text**:
The delivery text first prepared for a session.

**Current text**:
The editable version of a history entry's delivery text used for later copy actions.

**Custom term**:
A user-authored canonical spelling for a name, acronym, product, or specialist phrase.

**Correction rule**:
A mapping from a specific recognized form to its canonical form.

**Lexicon scope**:
The speech-language range in which a custom term or correction rule applies.

**Starter lexicon**:
The initial editable collection of custom terms and correction rules provided to a new user.

**Applied replacement**:
A record that a custom term or correction rule changed prepared text.

**Snippet**:
A mapping from a spoken trigger phrase to a literal saved expansion.

**Partial result**:
A valid raw transcript from only part of the intended capture.

**Speech locale**:
The language and regional speech model used for a dictation session.

**Speech asset**:
An operating-system-managed model required for a speech locale.

**Formatting availability**:
Whether smart formatting can accept a request at a given time.

## Delivery and history

**Insertion target**:
The text control intended to receive delivery text.

**Delivery agent**:
The application process able to write to an insertion target.

**Delivery**:
The act of placing delivery text into an insertion target.

**Delivery attempt**:
One attempt to deliver already prepared text.

**Awaiting delivery**:
A recoverable session state in which delivery text exists but no insertion target has accepted it.

**Recovery copy**:
Delivery text made available for manual recovery after automatic delivery cannot complete.

**History entry**:
The local record of a dictation session that produced useful text.

**History retention**:
The period after which OpenYap deletes a local history entry.
