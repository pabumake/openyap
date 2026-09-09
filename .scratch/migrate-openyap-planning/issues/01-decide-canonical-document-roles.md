# Decide the canonical role of each existing planning document

Type: grilling

Status: resolved

Parent: [Migrate OpenYap planning into the agent framework](../map.md)

## Question

After the migration, which existing documents are authoritative, historical evidence, supporting detail, or superseded? Decide the role of `ROADMAP.md`, `CHANGELOG.md`, `CONTEXT.md`, `docs/domain/`, `docs/adr/`, `docs/research/`, and `docs/prototypes/` so later tickets can move content without duplicating ownership.

## Answer

The documents have these canonical roles after the migration:

- `ROADMAP.md` is the authoritative portfolio-level plan. It owns whether an effort is current, next, later, or parked, plus the order of active work. Each entry stays short and links to its Wayfinder map when one exists. The linked map owns the effort's destination, unresolved decisions, dependencies, and resolution history. If the two disagree, `ROADMAP.md` decides whether and when the effort is active; the Wayfinder map decides what the effort means and how its open questions are resolved.
- `CHANGELOG.md` is the authoritative product release record and the release-notes data consumed by the app. It records shipped changes, not future plans.
- `CONTEXT.md` is the authoritative glossary for canonical product vocabulary. It contains no implementation detail.
- `docs/domain/` contains authoritative product behavior, invariants, and concrete scenarios that test the glossary. `docs/domain/dictation-lifecycle.md` owns the normative lifecycle behavior.
- `docs/adr/` contains authoritative accepted architectural decisions and their rationale. An accepted ADR remains authoritative until another ADR supersedes it.
- `docs/research/` contains supporting evidence. A research note can preserve facts, options, and the reasoning available at the time, but sections named `Decision` or `Recommendation` do not override a current spec, Wayfinder resolution, or ADR.
- `docs/prototypes/` contains non-authoritative artifacts used to test or demonstrate an idea. A prototype's behavior is not a product commitment. Live tickets, domain documents, and ADRs may link to useful prototypes.

The migration should preserve useful research and prototypes as supporting assets. It should remove duplicated ownership rather than deleting evidence solely because a later document became authoritative.
