# Initial evidence

Measured on 2026-09-10 with an Apple M5 MacBook Air with 16 GB memory, macOS 26.6.2, FluidAudio `c7246f4`, model revision `7dd20fe`, and the corrected `int8-v2` encoder.

| Probe | Audio | Model load | Stop to final | Peak resident memory | WER | Result |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| English synthetic speech | 4.25 s | 203.80 s cold | 79 ms | 695 MB | 9.1% | One spelling error: `OpenYapp` |
| German synthetic speech | 3.82 s | 98 ms warm | 66 ms | 85 MB | 0% | Exact normalized match |
| Long repeated synthetic speech | 72.12 s | 94 ms warm | 252 ms | 134 MB | 5.9% | Completed without a seam crash |
| Silence | 5.00 s | 258 ms warm | 89 ms to failure | 80 MB | n/a | No text, history, or delivery |
| Cancel after 10 ms | 72.12 s | 141 ms warm | 140 ms to cancellation | 96 MB | n/a | No text, history, or delivery |

The model downloader accepted exactly 632,169,729 bytes after checking every file against the pinned Hugging Face revision's SHA-256 or Git blob hash.

## What this answers

The corrected FluidAudio model can transcribe a completed in-memory capture behind an interface that returns only a raw transcript. FluidAudio types do not enter the formatting, history, or delivery side of the prototype. The capture owner retained zero samples after finalization, successful failure handling, and cancellation.

The 203.8-second first load is the sharp edge. It included the host's first Core ML setup for this model. Later process launches loaded the model in about 0.1 seconds. A product flow should compile or warm the model during installation and must show progress if a session ever pays the cold cost.

Cancellation protects product behavior but does not prove prompt compute interruption. FluidAudio's batch call returned before the adapter discarded its result, about 140 ms after stop in this fixture.

## What remains open

- Synthetic `say` voices prove wiring, not real English or German accuracy. Release gates need fixed human recordings, accents, noise, and reference transcripts.
- This M5 result does not set the oldest supported Mac or memory floor.
- The installed Instruments `Power Profiler` refuses macOS recording. `powermetrics` requires an administrator in a live terminal, so energy remains unmeasured.
- The boundary probe checks stage ordering and type isolation. It does not link the production formatter, history store, or delivery agent into this throwaway executable.
