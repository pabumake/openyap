# Decide how active roadmap ideas become Wayfinder efforts

Type: grilling

Status: resolved

Parent: [Migrate OpenYap planning into the agent framework](../map.md)

Blocked by: 01

## Question

Which ideas in the current roadmap remain active, which one is next, and which are merely parked? Decide whether app-specific formatting profiles, voice commands, the native iOS capture and keyboard path, and encrypted sync need separate Wayfinder maps, ordinary local issues, or no active artifact yet.

## Answer

The roadmap ideas have these portfolio states and tracker homes:

- App-specific formatting profiles remain the single next product effort. They need a separate planning-only Wayfinder map whose destination is an implementation-ready product spec. The roadmap description is not ready to become an ordinary implementation issue because profile ownership, destination-app matching, fallback behavior, formatting choices, and history evidence still need decisions.
- Native iOS capture and keyboard delivery remain a later product effort. Start with a narrow Wayfinder map that carries execution through a physical-device feasibility result. It must test capture, background operation, communication between the containing app and keyboard, and text delivery. Do not map the full iOS client yet. The broader client stays later in `ROADMAP.md` until the feasibility result clears the route.
- Voice commands for editing selected text are parked. Keep one concise entry in `ROADMAP.md`, but create no Wayfinder map or ordinary issue until the effort is promoted.
- Optional encrypted sync is parked. Keep one concise entry in `ROADMAP.md`, but create no Wayfinder map or ordinary issue until the effort is promoted. Promotion must account for the accepted on-device processing, local retention, and transcript-history decisions.

No listed idea leaves the roadmap. No ordinary implementation issue should result directly from this migration decision.
