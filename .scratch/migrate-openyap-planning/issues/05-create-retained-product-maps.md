# Create Wayfinder maps for retained product efforts

Type: task

Status: resolved

Parent: [Migrate OpenYap planning into the agent framework](../map.md)

Blocked by: 02

## Question

Create the two maps selected by "Decide how active roadmap ideas become Wayfinder efforts":

- A planning-only map for app-specific formatting profiles, with an implementation-ready product spec as its destination.
- An execution-carrying map for native iOS capture and keyboard delivery, limited to a physical-device feasibility result for capture, background operation, containing-app and keyboard communication, and text delivery.

Give each map its first specifiable decision tickets. Carry over only live decisions and unresolved questions. Link existing research, prototypes, domain documents, and ADRs as supporting assets instead of copying their contents into the maps. Do not create active artifacts for parked voice commands or encrypted sync, and do not map the full iOS client before the feasibility result.

## Answer

Two open Wayfinder maps now retain the active product work. `app-specific-formatting-profiles` owns a macOS-first path to an implementation-ready specification through identity, matching, behavior, and interface-prototype decisions. Persistence migration and final acceptance details remain in fog.

`ios-capture-keyboard-feasibility` explicitly carries execution through prerequisite verification, a narrow prototype on the iPhone 15 Pro Max, and a measured choice between keyboard delivery and the documented pasteboard fallback. Full-client planning remains in fog. Both maps link the existing research, lifecycle guide, prototype, and final ADR paths rather than copying them. No active artifact was created for voice commands or encrypted sync.
