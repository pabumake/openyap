# ADR 0002: Preserve transcript stages in local history

Status: Accepted

Date: 2026-08-23

## Context

OpenYap needs to show what smart formatting removed, what the word list replaced, what snippets expanded, and what the user changed later. Saving only raw and final text would allow a visual diff, but it could not assign changes to the correct step. Reapplying the current word list or snippets would also make old history change when an entry changes.

Text history is sensitive. Unlimited retention is convenient, but it is a poor default for an app that records everyday dictation.

## Decision

Each useful session stores five local text snapshots: raw transcript, formatted transcript, word-list text, initial delivery text, and current text. The first four are immutable. The user can edit current text. Older rows without word-list text treat their initial delivery text as that stage.

OpenYap also stores a snapshot of each deterministic word-list replacement and snippet expansion. Later changes to terms, correction rules, and snippets affect future dictations only.

History expires after 30 days by default. The user can select 90 days or retention until manual deletion. OpenYap never stores microphone audio.

## Consequences

- The app can show smart cleanup, word-list changes, snippet expansions, and manual edits separately.
- History remains understandable after a rule is edited or deleted.
- Entries use more storage than a single final string, but transcript text is small compared with audio.
- Reducing the retention period can delete entries immediately, so the app asks for confirmation.
- Cross-device history needs a later storage and privacy decision.

## Alternatives considered

### Store only raw and final text

This uses less storage. It cannot reliably separate language-model cleanup from deterministic replacements or manual edits.

### Recompute history with the current word list

This avoids replacement snapshots. It silently changes old results and breaks the meaning of copied or delivered text.

### Keep history until deletion by default

This maximizes recovery time. It retains sensitive dictated text longer than necessary for a default setting.

## Revisit when

Revisit the storage design before enabling cross-device sync, organization retention policies, or full edit revision history. Any change must preserve raw text and explain whether old entries can change.
