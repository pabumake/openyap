# Migrate OpenYap planning into the agent framework

Label: `wayfinder:map`

Status: resolved

## Destination

OpenYap has repository-level agent guidance, a configured local Markdown tracker, corrected planning-document structure, and active future work represented by properly scoped Wayfinder maps and tickets. Release history and useful research remain available. This migration does not implement application features.

## Notes

- This effort explicitly carries execution through the planning-document migration. It may edit agent configuration, local tracker files, planning documents, domain documentation, ADR identities, and links.
- Do not implement application features while working this map.
- Use the grilling and domain-modeling skills for human decisions. Use research only when a decision needs evidence outside this repository.
- `CHANGELOG.md` is product data consumed by the app, not a planning backlog.
- OpenYap is a single-context repository.
- Local Markdown issues under `.scratch/` are versioned project records, not disposable files.

## Decisions so far

<!-- Closed tickets are indexed here by name. The answer remains in the ticket. -->

- [Decide the canonical role of each existing planning document](issues/01-decide-canonical-document-roles.md): `ROADMAP.md` owns portfolio priority, while release history, domain language and behavior, architectural decisions, research, prototypes, and Wayfinder maps each have distinct owners.
- [Decide how active roadmap ideas become Wayfinder efforts](issues/02-decide-active-product-efforts.md): Formatting profiles are next, iOS feasibility is later, and voice commands plus encrypted sync are parked; only the first two get Wayfinder maps now.
- [Normalize the domain-document boundaries](issues/03-normalize-domain-document-boundaries.md): `CONTEXT.md` now owns terms only, lifecycle behavior lives in the domain guide, privacy and retention details remain in their ADRs, and updater trust belongs to the native-client ADR.
- [Repair ADR identities and references](issues/04-repair-adr-identities.md): iOS capture remains ADR 0002, transcript history is ADR 0003, and native Apple clients are ADR 0004; filenames, headings, and inbound links now agree.
- [Create Wayfinder maps for retained product efforts](issues/05-create-retained-product-maps.md): formatting profiles now have a macOS-first specification map, and iOS has an execution-carrying physical-device feasibility map; parked ideas have no active artifacts.
- [Refactor the roadmap as the authoritative portfolio index](issues/06-refactor-roadmap-as-portfolio-index.md): the roadmap now records release 0.2.0 and portfolio order, links both active maps, parks the remaining ideas, and is the README's planning entry point.
- [Verify the migrated planning system](issues/07-verify-migrated-planning-system.md): links, ADR identities, issue metadata, dependencies, frontiers, terminal statuses, and the documentation-only diff all pass final validation.

## Not yet specified

None.

## Frontier

None.

## Out of scope

- Implementing app-specific formatting profiles, voice commands, iOS clients, encrypted sync, or any other application feature.
- Rewriting release history in `CHANGELOG.md`.
- Reconsidering accepted product architecture unless the migration exposes a direct contradiction or an ADR can no longer be identified correctly.
