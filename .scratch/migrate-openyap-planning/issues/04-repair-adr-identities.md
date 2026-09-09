# Repair ADR identities and references

Type: task

Status: resolved

Parent: [Migrate OpenYap planning into the agent framework](../map.md)

Blocked by: 01

## Question

Give every accepted ADR a unique sequential identity, update inbound references, and verify that renaming files does not change the decisions they record. The repository currently has two unrelated ADRs numbered `0002`.

## Answer

The iOS capture and keyboard decision remains ADR 0002. Transcript history is now ADR 0003, and native Apple clients are now ADR 0004. Their filenames and headings match their unique sequential identities. Dates, status, rationale, decisions, and consequences remain intact, including the updater trust constraints moved into ADR 0004 by the preceding ticket. All inbound relative references use the corrected paths.
