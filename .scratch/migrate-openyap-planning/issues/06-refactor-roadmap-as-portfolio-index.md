# Refactor the roadmap as the authoritative portfolio index

Type: task

Status: resolved

Parent: [Migrate OpenYap planning into the agent framework](../map.md)

Blocked by: 05

## Question

Refactor `ROADMAP.md` after every retained idea has an agreed home. Keep it as the authoritative source for portfolio status and order, with concise current, next, later, and parked entries that link to Wayfinder maps where they exist. Remove ticket-level decisions and unresolved questions that belong in those maps, and leave one obvious route from the repository root to the local Markdown tracker.

## Answer

`ROADMAP.md` now owns only portfolio status and order. It identifies version 0.2.0 as the current release and links `CHANGELOG.md`, places formatting profiles under Next with its map, places native iOS feasibility under Later with its map, and keeps voice commands and encrypted sync under Parked without child issues. Shipped updater work no longer appears as future planning.

`README.md` now points contributors to the roadmap, which provides the single route into the active `.scratch/` maps.
