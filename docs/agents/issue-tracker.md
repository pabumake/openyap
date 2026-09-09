# Issue tracker: GitHub Issues

OpenYap uses [GitHub Issues](https://github.com/pabumake/openyap/issues) as its issue tracker. Use `gh` from the repository root and pass `--repo pabumake/openyap` when repository inference is unavailable. Do not create a local issue mirror under `.scratch/`.

## Conventions

- A Wayfinder map is an open parent issue with the `wayfinder:map` label. Its body contains Destination, Notes, Decisions so far, Not yet specified, and Out of scope.
- A child ticket is a native sub-issue. Its title begins with a two-digit order in brackets, such as `[01]`, and its body states the question.
- Every child ticket has exactly one type label: `type:research`, `type:prototype`, `type:grilling`, or `type:task`.
- Native issue dependencies record blocking relationships. Do not duplicate them as a `Blocked by` line in the body.
- The `wayfinder:frontier` label marks the next unblocked ticket for an open map.
- An unclaimed ticket is open without `status:claimed`. A claimed ticket is open with `status:claimed`. A resolved ticket is closed as completed.
- Use issue comments for conversation and progress notes. Keep the answer in the closing comment so the decision remains next to its discussion.
- Triage labels are independent of Wayfinder type and status. See [triage-labels.md](triage-labels.md).

## Common operations

Before changing issues, confirm authentication:

```sh
gh auth status
```

Fetch a ticket with its relationships:

```sh
gh issue view NUMBER \
  --repo pabumake/openyap \
  --json number,title,body,state,labels,parent,subIssues,subIssuesSummary
```

Create a child ticket with structured relationships:

```sh
gh issue create \
  --repo pabumake/openyap \
  --title "[NN] Question title" \
  --body "## Question" \
  --label "type:task" \
  --parent PARENT_NUMBER \
  --blocked-by BLOCKER_NUMBER
```

Omit `--blocked-by` when the ticket has no blocker.

## Frontier

For each open map, inspect its open sub-issues and their native dependencies. A ticket is eligible when it is open, is not claimed, and every issue blocking it is closed. The eligible ticket with the lowest `[NN]` prefix is the frontier.

Exactly one eligible ticket carries `wayfinder:frontier`. Remove the label when no ticket is eligible. Before finishing any issue operation, compare the label with the calculated frontier and correct stale labels.

## Claim

Re-fetch the issue immediately before claiming it. Confirm that it is open, unclaimed, and carries `wayfinder:frontier`. Save the claim before starting work:

```sh
gh issue edit NUMBER \
  --repo pabumake/openyap \
  --add-label "status:claimed" \
  --remove-label "wayfinder:frontier"
```

Then recalculate the parent map's frontier. This second calculation matters when a map has several independent tickets.

## Resolve

Post a closing comment headed `## Answer` that records the result and links permanent evidence. Close the issue as completed, remove `status:claimed`, and add a one-line gist with a link under the parent issue's Decisions so far section.

```sh
gh issue comment NUMBER --repo pabumake/openyap --body-file ANSWER_FILE
gh issue close NUMBER --repo pabumake/openyap --reason completed
gh issue edit NUMBER --repo pabumake/openyap --remove-label "status:claimed"
```

Recalculate the frontier after updating the parent. Close the parent map only when its destination is reached and nothing remains under Not yet specified.

## Skill routing

When a skill says "publish to the issue tracker," create a GitHub issue with the appropriate labels and relationships. When a skill says "fetch the relevant ticket," use the issue number or URL supplied by the user and retrieve it with `gh issue view`.
