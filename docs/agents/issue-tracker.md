# Issue tracker: Local Markdown

Issues and specs for this repository live as versioned Markdown files in `.scratch/`. The directory name does not mean that its contents are disposable.

## Conventions

- One feature per directory: `.scratch/<feature-slug>/`
- The spec is `.scratch/<feature-slug>/spec.md`
- Implementation issues are one file per ticket at `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01`, never a single combined tickets file
- Triage state is recorded as a `Status:` line near the top of each issue file. See `triage-labels.md` for the role strings.
- Comments and conversation history append to the bottom of the file under a `## Comments` heading.

## When a skill says "publish to the issue tracker"

Create a new file under `.scratch/<feature-slug>/`, creating the directory if needed.

## When a skill says "fetch the relevant ticket"

Read the file at the referenced path. The user will normally pass the path or the issue number directly.

## Wayfinding operations

The Wayfinder skill uses one map file with one child file per ticket.

- **Map**: `.scratch/<effort>/map.md`, containing Notes, Decisions so far, Not yet specified, and Out of scope.
- **Child ticket**: `.scratch/<effort>/issues/NN-<slug>.md`, numbered from `01`, with the question in the body. A `Type:` line records `research`, `prototype`, `grilling`, or `task`. A `Status:` line records `open`, `claimed`, or `resolved`.
- **Blocking**: a `Blocked by: NN, NN` line near the top. A ticket is unblocked when every file it lists has `Status: resolved`.
- **Frontier**: scan `.scratch/<effort>/issues/` for files with `Status: open` whose blockers are resolved. The lowest numbered ticket wins.
- **Claim**: set `Status: claimed` and save before starting work.
- **Resolve**: append the answer under an `## Answer` heading, set `Status: resolved`, then append a gist and relative link to the map's Decisions so far section.
