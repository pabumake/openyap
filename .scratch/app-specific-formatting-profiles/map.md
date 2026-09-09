# App-specific formatting profiles

Label: `wayfinder:map`

Status: open

## Destination

An implementation-ready, macOS-first product specification for app-specific formatting profiles. The specification defines shared profile semantics that later Apple clients can use without assuming that their app-detection or user-interface capabilities match macOS.

## Notes

- This map owns product decisions and planning only. It does not carry feature implementation.
- Existing behavior and terminology remain in [the dictation lifecycle](../../docs/domain/dictation-lifecycle.md) and [the domain glossary](../../CONTEXT.md).
- [The original Apple-platform research](../../docs/research/wispr-flow-clone-apple-platforms.md) is supporting evidence, not a product specification.
- [The lifecycle prototype](../../docs/prototypes/dictation-lifecycle.html) can test session and history consequences without defining profile behavior.
- [ADR 0001](../../docs/adr/0001-on-device-processing-and-local-retention.md), [ADR 0003](../../docs/adr/0003-preserve-transcript-stages-in-local-history.md), and [ADR 0004](../../docs/adr/0004-keep-native-apple-clients.md) constrain processing, history evidence, and client architecture.

## Decisions so far

<!-- Closed tickets are indexed here by name. The answer remains in the ticket. -->

## Not yet specified

- Persistence migration for profiles remains in fog until identity, ownership, matching, and lifecycle decisions define what must migrate.
- Final acceptance details remain in fog until profile behavior and the management prototype make observable outcomes precise.

## Frontier

- [Define profile identity, ownership, and lifecycle](issues/01-define-profile-identity-ownership-and-lifecycle.md)

## Out of scope

- Implementing profiles during this planning effort.
- Replacing correction rules, snippets, history, or the existing text-preparation pipeline.
- Designing platform-specific interfaces for Apple clients other than macOS.
