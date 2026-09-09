# iOS capture and keyboard feasibility

Label: `wayfinder:map`

Status: open

## Destination

A measured physical-device feasibility result for native iOS capture, background operation, containing-app and keyboard communication, and text delivery on the iPhone 15 Pro Max. This map carries execution through the prototype and ends with a supported delivery-path decision. It does not plan the full iOS client.

## Notes

- [The Apple-platform research](../../docs/research/wispr-flow-clone-apple-platforms.md) records the public-API constraints and proposed experiment. Verify its claims against the installed toolchain and device rather than copying them here.
- [The dictation lifecycle](../../docs/domain/dictation-lifecycle.md) defines session and recovery behavior. [The lifecycle prototype](../../docs/prototypes/dictation-lifecycle.html) is supporting evidence for state transitions.
- [ADR 0001](../../docs/adr/0001-on-device-processing-and-local-retention.md), [ADR 0002](../../docs/adr/0002-split-ios-capture-from-keyboard-delivery.md), and [ADR 0004](../../docs/adr/0004-keep-native-apple-clients.md) constrain processing, process ownership, fallback, and native client architecture.
- Record the signing team, device and operating-system versions, build configuration, observed process transitions, and delivery results so another developer can repeat the test.

## Decisions so far

<!-- Closed tickets are indexed here by name. The answer remains in the ticket. -->

## Not yet specified

- Full iOS-client screens, onboarding, persistence, history, settings, and release planning remain in fog until the feasibility result selects a delivery path.

## Frontier

- [Verify signing capabilities and physical-device prerequisites](issues/01-verify-signing-capabilities-and-device-prerequisites.md)

## Out of scope

- Building the full iOS client.
- Using private APIs or treating simulator behavior as physical-device proof.
- Reconsidering the on-device processing boundary.
