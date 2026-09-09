# Normalize the domain-document boundaries

Type: grilling

Status: resolved

Parent: [Migrate OpenYap planning into the agent framework](../map.md)

Blocked by: 01

## Question

Which material belongs in the domain glossary, the dictation-lifecycle document, and ADRs? Decide how to keep canonical product terms in `CONTEXT.md` while moving invariants, scenarios, and implementation constraints to their proper owners without changing accepted product meaning.

## Answer

`CONTEXT.md` is now a glossary in the Domain Modeling format. It keeps OpenYap's canonical terms and short definitions, while defaults, platform examples, implementation details, update-system terms, and behavioral invariants have moved out.

`docs/domain/dictation-lifecycle.md` now owns session, audio-selection, text-preparation, history, and delivery rules alongside the existing scenarios. It points to the on-device ADR for local processing and audio retention, and to the history ADR for exact snapshots and retention choices. Updater trust constraints now live in the native-client ADR. No product behavior changed.
