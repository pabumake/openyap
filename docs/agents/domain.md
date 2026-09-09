# Domain docs

This file explains how engineering skills should read OpenYap's domain documentation before exploring the codebase.

## Before exploring, read these

- Read `CONTEXT.md` at the repository root.
- Read ADRs under `docs/adr/` that touch the area being changed.
- Read focused material under `docs/domain/` when it covers the workflow being changed.

If one of these paths does not exist, proceed without creating it. The domain-modeling skill creates domain files only when the work resolves a term or qualifying architectural decision.

## File structure

OpenYap is a single-context repository:

```text
/
├── CONTEXT.md
├── docs/
│   ├── adr/
│   └── domain/
└── OpenYap/
```

Do not create `CONTEXT-MAP.md` or context-specific glossaries unless the repository later gains genuinely separate product domains.

## Use the glossary's vocabulary

Use terms from `CONTEXT.md` in issue titles, specifications, tests, and code discussions. Do not substitute a synonym when the glossary has chosen a canonical term.

If a required concept is missing, either reconsider whether it belongs to the product domain or record the new term through the domain-modeling skill.

## Flag ADR conflicts

Call out any proposal that contradicts an existing ADR. Do not silently replace an accepted decision.
