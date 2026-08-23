# OpenYap: a native Wispr Flow-style app for macOS and iOS

Date: 2026-08-23

## Question

Can OpenYap reproduce the useful parts of Wispr Flow as a native, private, offline app on this Mac and an iPhone 15 Pro Max?

The first release targets macOS 26 and iOS 26. It supports English and German. It must provide system-wide dictation, smart transcript cleanup, custom words, snippets, and local history. The intended distribution is the owner's devices rather than the App Store.

## Short answer

Yes on macOS. Apple exposes the same speech and cleanup frameworks on iOS 26, and the iPhone 15 Pro Max supports Apple Intelligence. iOS still imposes one awkward constraint: a custom keyboard extension cannot access the microphone. The containing iOS app must own audio capture and transcription. The keyboard can only request capture, observe shared state, and insert delivery text.

Apple's current APIs remove the need for a transcription server. `SpeechAnalyzer` and `SpeechTranscriber` process audio on the device, while the Foundation Models framework can clean punctuation, filler words, and false starts. Both target devices support Apple Intelligence. The Mac passed local availability checks. The iPhone still needs a physical-device check because it was not connected during this research.

## Relevant Wispr Flow behavior

Wispr calls the product "Flow." Its main job is short-form dictation into whichever app currently owns the text cursor. On desktop, the user holds a hotkey, speaks, and releases it to insert the result. A double press starts hands-free mode. On iOS, a custom keyboard supplies the microphone control. Wispr documents these behaviors in its [Flow overview](https://docs.wisprflow.ai/articles/2772472373-what-is-flow).

The useful feature set is broader than speech recognition:

| Capability | Wispr behavior | OpenYap v1 decision |
| --- | --- | --- |
| System-wide dictation | Desktop hotkey and iOS keyboard | Include |
| Progressive transcript | Text becomes available around the end of a recording | Include internally; show it in the capture UI |
| Smart formatting | Adds punctuation and capitalization, removes filler, and formats lists | Include |
| Backtrack | Resolves spoken corrections such as "Tuesday, actually Wednesday" | Include |
| Dictionary | Learns names, technical terms, and explicit misspelling corrections | Include explicit local entries |
| Snippets | Replaces a spoken trigger with saved text | Include plain-text snippets |
| History | Keeps prior transcripts and failed recordings | Include local text history |
| App-specific style | Changes tone for mail, work chat, or personal messages | Later |
| Context awareness | Reads nearby accessibility text and optional screen OCR | Later |
| Command mode | Edits selected or existing text by voice | Later |
| Cross-device sync | Syncs selected user data and notes | Later |
| Notes and statistics | Scratchpad, word count, WPM, and streaks | Statistics included on macOS; notes later |

Wispr's [Smart Formatting and Backtrack documentation](https://docs.wisprflow.ai/articles/5373093536-how-do-i-use-smart-formatting-and-backtrack) confirms that it handles grammar, punctuation, capitalization, filler words, false starts, lists, and spoken punctuation. Its [dictionary documentation](https://docs.wisprflow.ai/articles/4052411709-teach-flow-your-words-with-the-dictionary) distinguishes vocabulary boosting from exact misspelling replacement. Its [snippet documentation](https://docs.wisprflow.ai/articles/5784437944-create-and-use-snippets) defines case-insensitive spoken triggers that expand into saved text.

Wispr also reads limited text near the cursor and identifies the active app to improve names, formatting, and tone. That behavior requires sensitive accessibility access and is not needed for a useful first release. See Wispr's [Context Awareness documentation](https://docs.wisprflow.ai/articles/4678293671-Context-Awareness).

Unlike the proposed OpenYap design, Wispr currently requires an internet connection for transcription. Its [iPhone setup guide](https://docs.wisprflow.ai/articles/7453988911-set-up-the-flow-keyboard-on-iphone) says dictation fails offline. OpenYap can work offline after Apple installs the required speech assets.

## Apple speech stack

### Facts

Apple introduced `SpeechAnalyzer` on macOS 26 and iOS 26. An analyzer accepts an asynchronous sequence of audio buffers and sends results through each configured speech module's `AsyncSequence`. `SpeechTranscriber` returns volatile and finalized results, so OpenYap can show tentative text without committing it twice. Apple's [SpeechAnalyzer documentation](https://developer.apple.com/documentation/speech/speechanalyzer) describes the complete audio-to-results flow.

Apple says the new `SpeechTranscriber` model runs entirely on the device. It targets live, long-form, conversational, and distant speech. The model does not increase the application download size and receives updates through the operating system. See [Bring advanced speech-to-text to your app with SpeechAnalyzer](https://developer.apple.com/videos/play/wwdc2025/277/).

`AssetInventory` manages locale-specific speech assets. The app creates its transcriber, requests an asset installation supporting that module, and awaits `downloadAndInstall()`. The system keeps and shares installed assets across apps, subject to per-app locale reservation limits. See [AssetInventory](https://developer.apple.com/documentation/speech/assetinventory).

Apple explicitly states that `SpeechAnalyzer` transcriber modules do not send voice audio to Apple servers. The speech recognition authorization discussion for server-backed `SFSpeechRecognizer` does not apply to this processing path, although microphone permission still does. See [Asking permission to use speech recognition](https://developer.apple.com/documentation/speech/asking-permission-to-use-speech-recognition).

`SpeechTranscriber` is the preferred module for English and German because those locales use Apple's newer transcription model. `DictationTranscriber` is the runtime fallback for unsupported locales or unavailable hardware. It also exposes punctuation, emoji, and custom-language-model options. OpenYap should query `supportedLocale(equivalentTo:)` rather than hard-code assumptions.

`AnalysisContext.contextualStrings` can improve recognition of short custom phrases when using `DictationTranscriber`. Apple recommends one or two words per phrase and no more than 100 phrases. The first release should keep the main English and German path on `SpeechTranscriber`, then apply explicit dictionary corrections after recognition. See [AnalysisContext contextual strings](https://developer.apple.com/documentation/speech/analysiscontext/contextualstrings).

### Local verification on this Mac

Testing used an Apple silicon Mac on macOS 26 with Xcode 26 and the matching macOS and iOS SDKs.

A Swift runtime query returned:

```text
SpeechTranscriber.isAvailable=true
SpeechTranscriber English locales installed=true
SpeechTranscriber de_AT, de_CH, and de_DE supported=true
DictationTranscriber en_US installed=true
FoundationModels availability=available
```

The Mac currently has English `SpeechTranscriber` variants installed. German is supported but still needs an asset download. A local Foundation Models request also completed successfully:

```text
Input:  um I think we should meet Tuesday no actually Wednesday at three
Output: Sure, let's meet Wednesday at three.
```

The test proves availability, not production latency or general formatting quality. Those need a fixture set and measurements inside the signed app.

The active developer directory points to `/Library/Developer/CommandLineTools`, so ordinary `xcrun` commands cannot find the iOS SDK or `devicectl`. Build commands should initially set:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

Switching the system-wide path with `xcode-select` is optional and requires administrator approval.

## Smart cleanup with Foundation Models

### Facts

The Foundation Models framework exposes the on-device language model used by Apple Intelligence. It works offline and keeps prompt and output data on the device. Apple describes it as suited to summarization, extraction, classification, and text generation, but not advanced reasoning or world knowledge. See [Meet the Foundation Models framework](https://developer.apple.com/videos/play/wwdc2025/286/).

`SystemLanguageModel.default.availability` reports whether the model is ready, downloading, disabled, or unsupported. OpenYap must check that value before each formatting session and keep a non-model fallback. See [SystemLanguageModel](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel).

Apple lists the iPhone 15 Pro family and Apple silicon Macs as supported Apple Intelligence hardware. Device and Siri languages must use a supported language, Apple Intelligence must be enabled, and the model needs local storage. See [How to get Apple Intelligence](https://support.apple.com/en-euro/121115).

### Recommended cleanup pipeline

The raw transcript should remain the source of truth. The language model gets one bounded request after the user stops capture. Its instruction is to preserve meaning, add punctuation and capitalization, remove clear filler words, resolve explicit self-corrections, and return only rewritten text.

Process each transcript in this order:

1. Join finalized speech segments by their audio ranges. Never append a volatile segment to committed text.
2. Ask Foundation Models for smart cleanup when the model is available and Smart Formatting is enabled.
3. Reject an empty result, an output over twice the input length, or a request that throws. Use the unformatted transcript in those cases.
4. Apply case-insensitive dictionary correction rules with token boundaries.
5. Expand snippet triggers last so the language model cannot rewrite saved addresses, signatures, URLs, or code.
6. Insert the finished text and store the raw and formatted versions in local history.

This pipeline gives dictionary and snippet behavior deterministic precedence. It also makes model failure boring: the user still gets the transcript.

## macOS architecture

Use SwiftUI for settings and history, with AppKit adapters for global input, the floating recording panel, application focus, and pasteboard handling.

The main process owns these components:

- `AudioCaptureService` streams microphone buffers from `AVAudioEngine`.
- `AppleSpeechTranscriptionEngine` manages `SpeechAnalyzer`, transcriber assets, progressive results, finalization, and cancellation.
- `AppleTranscriptFormatter` wraps `LanguageModelSession` and the deterministic fallback.
- `MacShortcutMonitor` installs a `CGEvent` tap for key-down, key-up, and modifier events. The default shortcut is `Fn+Space`, with hold-to-talk and double-tap hands-free behavior.
- `MacTextInserter` temporarily places delivery text on `NSPasteboard`, posts Command+V to the previously focused process, and restores the old pasteboard only if another app has not changed it.
- `LocalHistoryStore`, `DictionaryStore`, and `SnippetStore` persist text data locally.

The app should use a menu-bar item and an `NSPanel` that does not activate the app or steal focus. The panel shows preparing, capturing, finalizing, preparing text, awaiting delivery, and error states. It should not display a volatile segment as committed text.

macOS requires microphone permission to capture audio. Global shortcut observation and synthetic text insertion require Accessibility trust. `AXIsProcessTrustedWithOptions` can check access and open the system prompt. See [AXIsProcessTrustedWithOptions](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions). `CGEvent` provides event taps and synthetic keyboard events. See [CGEvent](https://developer.apple.com/documentation/coregraphics/cgevent).

Secure text fields, apps using Secure Keyboard Entry, and custom editors may reject the shortcut or paste operation. OpenYap should leave the session awaiting delivery and expose a recovery copy rather than retrying blind.

## iOS architecture

### The hard platform rule

Apple's custom-keyboard guide states that keyboard extensions cannot access the microphone. Full Access adds network, shared-container, and pasteboard capabilities, but it does not grant microphone capture. See [Custom Keyboard](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html).

Third-party keyboards also disappear in secure fields, phone-pad fields, and apps that reject the keyboard extension point. Apple documents those limitations in [Creating a custom keyboard](https://developer.apple.com/documentation/uikit/creating-a-custom-keyboard).

Wispr encounters the same constraint. Its current iOS 26.4 documentation says microphone activation may open the containing app and require a manual swipe back while dictation continues. That is strong evidence that OpenYap should make the transition explicit rather than hide it. See [Set up the Flow keyboard on iPhone](https://docs.wisprflow.ai/articles/7453988911-set-up-the-flow-keyboard-on-iphone).

### Recommended flow

The iOS app owns the microphone, speech analyzer, formatter, history, permissions, and onboarding. A `UIInputViewController` keyboard extension owns only text insertion and a compact control row.

The normal keyboard flow is:

1. The user selects the OpenYap keyboard and taps its microphone button.
2. The extension records a session identifier and keyboard heartbeat, then opens the containing app through an OpenYap URL.
3. The app starts capture and a Live Activity. The user swipes back to the previous app.
4. The keyboard observes shared capture state and shows Stop and Cancel controls.
5. On Stop, the app finalizes and formats the transcript, then writes the result for that session.
6. The active keyboard calls `textDocumentProxy.insertText`. If it is no longer active, the app copies the result to the pasteboard and keeps it in history for recovery.

The iPhone 15 Pro Max Action Button and a Control Center control should invoke the same start and stop action. Apple provides `AudioRecordingIntent` for this purpose. On iOS, an audio-recording intent must start a Live Activity and keep it active throughout recording or the system stops the recording. See [AudioRecordingIntent](https://developer.apple.com/documentation/appintents/audiorecordingintent). The app also needs the audio background mode so a user-started recording continues after returning to the host app. See [`AVAudioSession.Category.record`](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/record).

### App and extension communication

An App Group is the clean bridge. Apple permits an app and its extension to share files, preferences, and limited interprocess communication through the group container. See [Configuring App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups).

Use `group.dev.pabu.openyap` and exchange small, versioned records:

```text
DictationCommand { sessionID, action, requestedAt }
DictationSnapshot { sessionID, state, volatileText, deliveryText, error, updatedAt }
KeyboardPresence { sessionID, hostBundleHint, updatedAt }
```

Store each update atomically. The keyboard can poll while visible and use a Darwin notification as a wake-up hint. The shared record remains authoritative because Darwin notifications carry no durable payload.

App Groups may depend on the Apple developer membership attached to Xcode. Apple says available capabilities vary by program membership. Confirm App Groups and Background Modes against the signing team before building the bridge. See [Supported capabilities for iOS](https://developer.apple.com/help/account/reference/supported-capabilities-ios).

If the account is only a free Personal Team and cannot provision App Groups, v1 must use a reduced route. The app opens by URL, captures speech, places delivery text on the general pasteboard, and asks the user to return and paste. Free provisioning also expires after seven days. See [Choosing a membership](https://developer.apple.com/support/compare-memberships/). This fallback works, but it is not Flow-like keyboard insertion.

## Domain model

The shared vocabulary lives in [CONTEXT.md](../../CONTEXT.md). It separates the full dictation session from microphone capture, the raw transcript from delivery text, and successful transcription from successful delivery.

The most important correction to the initial architecture is that insertion failure does not make a dictation fail. If delivery text exists, the session remains awaiting delivery and can expose a recovery copy or retry another insertion target. [Dictation lifecycle scenarios](../domain/dictation-lifecycle.md) define cancellation, interruption, duplicate commands, stale updates, ownership changes, and delivery retries.

Two durable decisions have their own records:

- [ADR 0001](../adr/0001-on-device-processing-and-local-retention.md) fixes on-device processing and local retention as the v1 privacy boundary.
- [ADR 0002](../adr/0002-split-ios-capture-from-keyboard-delivery.md) records the iOS split between the containing capture host and keyboard delivery agent.

## Proposed project boundaries

Use an XcodeGen project so target definitions, entitlements, and build settings remain reviewable. The repository already has `xcodegen` installed.

The future implementation should contain:

- A shared Swift package with transcript models, session state, formatting rules, dictionary and snippet matching, and service protocols.
- A macOS menu-bar target with AppKit platform adapters.
- An iOS containing-app target with SwiftUI history, dictionary, snippets, language setup, and capture UI.
- An iOS custom-keyboard target with the App Group bridge and `textDocumentProxy` insertion.
- A WidgetKit target for the Live Activity, Control Center control, and Action Button intent.

The central protocols should be small:

```swift
protocol TranscriptionEngine {
    func prepare(locale: Locale) async throws
    func start() async throws -> AsyncThrowingStream<TranscriptionUpdate, Error>
    func stop() async throws -> RawTranscript
    func cancel() async
}

protocol TextPreparer {
    func prepare(_ transcript: RawTranscript, locale: Locale) async -> DeliveryText
}

protocol TextInserter {
    func insert(_ text: DeliveryText) async throws
}

protocol DictationBridge {
    func send(_ command: DictationCommand) async throws
    func snapshots(for sessionID: UUID) -> AsyncStream<DictationSnapshot>
}
```

Use one explicit state machine on both platforms:

```text
requested -> preparing -> capturing -> finalizing -> preparing text -> awaiting delivery
awaiting delivery -> delivering -> delivered
delivering -> awaiting delivery on rejection
awaiting delivery -> discarded
any pre-delivery active state -> cancelled
any state without usable text -> failed
finalizing with partial text -> preparing text, marked partial
formatting error -> awaiting delivery with raw transcript
```

Awaiting-delivery sessions are dormant. A device can retain several in local history while only one session captures, processes, or attempts delivery.

Do not add a backend, account system, analytics, payment code, cloud transcription, or cross-device sync in v1. Store transcripts and user-authored entries locally. Do not retain audio by default.

## Verification plan

### Feasibility gates

1. Sign into Xcode and inspect the selected team. Confirm that the iOS app, keyboard, and widget can share one App Group and use Background Modes.
2. Connect, unlock, and trust the iPhone 15 Pro Max. The previous `devicectl` check found no attached device.
3. On the phone, query `SpeechTranscriber.isAvailable`, English and German supported locales, installed assets, and Foundation Models availability.
4. Build a narrow vertical test before the full UI. Start capture from an `AudioRecordingIntent`, keep a Live Activity active, swipe back to a host text field, stop from the keyboard, and insert the App Group result.
5. If that test cannot maintain capture or keyboard state on the installed iOS 26 release, ship the Action Button to pasteboard flow first. Do not invent private APIs to bypass iOS isolation.

### Automated checks for the later implementation

- Merge volatile and finalized results without missing or duplicated text.
- Finalize cleanly after normal stop, silence, cancellation, audio interruption, and analyzer error.
- Map `en_US`, `en_GB`, and `de_DE` requests through `supportedLocale(equivalentTo:)`.
- Fall back to raw text when Foundation Models is unavailable, rejects a prompt, returns empty text, or produces abnormal expansion.
- Apply dictionary corrections only at token boundaries.
- Expand snippets case-insensitively without rewriting their saved content.
- Validate every session-state transition and reject stale App Group updates from an older session.
- Preserve the existing macOS pasteboard when insertion succeeds and avoid overwriting a newer user copy.

### Physical acceptance checks

On macOS, test TextEdit, Notes, Safari, Mail, and Terminal. Cover hold-to-talk, hands-free mode, Escape cancellation, Unicode, multiple paragraphs, focus preservation, clipboard restoration, permission denial, Secure Keyboard Entry, and offline use.

On the iPhone, test Notes, Messages, Mail, and Safari. Cover keyboard activation, the app transition and swipe back, Action Button start and stop, Control Center, Live Activity, delayed final results, microphone denial, audio interruption, model download, airplane mode, secure fields, and fields that reject custom keyboards.

After assets are installed, a 30-second English or German capture must complete in airplane mode. A reasonable first performance budget is three seconds from Stop to insertion on the warm Mac path and five seconds on the warm iPhone path. Measure these numbers before treating them as product guarantees.

For raw speech accuracy, use at least 20 scripted phrases per language in a quiet room, including names, numbers, punctuation, corrections, and snippet triggers. Measure word error rate before smart cleanup. A starting acceptance threshold is at most 10 percent word error rate for the test speaker and microphone.

## Facts, inferences, and open questions

### Established facts

- The development Mac supports both `SpeechTranscriber` and Foundation Models.
- English speech assets are installed on the Mac, and German assets are supported.
- The iPhone 15 Pro Max supports Apple Intelligence when its software, region, language, and settings meet Apple's requirements.
- `SpeechAnalyzer` transcription can run without sending audio to Apple servers.
- iOS custom keyboards cannot access the microphone.
- `AudioRecordingIntent` requires a Live Activity for continued iOS recording.

### Architectural inferences

- A private, offline macOS Flow clone is straightforward with public APIs.
- The best public iOS approximation is a containing recording app plus keyboard, App Group, Live Activity, and App Intent controls.
- Foundation Models is suitable for bounded transcript cleanup, but deterministic fallbacks must protect the core dictation path.
- Context Awareness should wait. Reading surrounding application text expands the privacy and compatibility risk without being necessary for v1.

### Open questions and how to resolve them

- **Does the current Apple team support App Groups and the required background capability?** Check Signing and Capabilities in Xcode with the actual account.
- **Does `SpeechTranscriber` expose English and German assets on the iPhone 15 Pro Max?** Run the same locale query used on the Mac after connecting the phone.
- **Can the keyboard remain responsive while the containing app records in the background on the installed iOS 26 build?** Prove the six-step keyboard flow on the physical phone.
- **What is warm and cold formatting latency on A17 Pro?** Time 30 representative English and German transcripts with Instruments and signposts.
- **How much meaning does smart cleanup alter?** Compare raw and formatted fixture results, then tighten the prompt and safety thresholds before enabling it by default.

## Recommendation

Build OpenYap in two implementation slices after this research note is accepted.

The first slice is the macOS vertical path: microphone to `SpeechAnalyzer`, Foundation Models cleanup, temporary-pasteboard insertion, and a minimal menu-bar UI. This validates the product on hardware that is already confirmed ready.

The second slice starts with the iPhone feasibility gate, not with screen design. Confirm signing, App Groups, `AudioRecordingIntent`, Live Activity lifetime, background capture, and keyboard insertion on the physical iPhone 15 Pro Max. Once that path works, add history, dictionary, snippets, onboarding, and controls around it.

This order keeps the hard iOS constraint visible and produces a useful Mac app even if the phone needs the pasteboard fallback.
