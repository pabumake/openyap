# Parakeet TDT on macOS

Date: 2026-09-09

## Question

How should a native Swift OpenYap app on Apple silicon offer Parakeet TDT through a curated model catalog, while using Hugging Face-compatible distribution where it is practical?

## Decision

Prototype Parakeet TDT v3 with [FluidAudio](https://github.com/FluidInference/FluidAudio) and its Core ML conversion. Keep Apple Speech installed and selected by default. Present Parakeet as an optional download for users who want a local multilingual model.

The prototype must use the corrected `int8-v2` encoder added in [FluidAudio commit `c7246f4`](https://github.com/FluidInference/FluidAudio/commit/c7246f4dc78d05f75cdfc5a550cd72ced0c658bf). The latest tagged release, [v0.15.6](https://github.com/FluidInference/FluidAudio/releases/tag/v0.15.6), predates that fix. Pin the prototype to the fix commit. Move to the first tagged release that contains it before shipping.

Implement final transcription after capture stops before attempting live preview. Parakeet TDT v3 is an offline model. FluidAudio's sliding-window API can produce provisional updates, but it repeatedly transcribes overlapping fixed windows and is not cache-aware streaming. This fits OpenYap's volatile and final segment vocabulary, but its latency and stitching behavior need separate product validation.

Use Hugging Face as a distribution source for approved, format-specific artifacts. "Hugging Face compatible" should not mean that OpenYap can load an arbitrary repository. NeMo, ONNX, MLX, GGUF, and Core ML checkpoints are not interchangeable.

## Why FluidAudio is the first choice

| Runtime | Native Apple integration | Parakeet v3 format and size | Output mode | Assessment |
| --- | --- | --- | --- | --- |
| FluidAudio | Swift Package Manager, Swift 6, Core ML, macOS 14+ and iOS 17+; CPU and Neural Engine placement | Compiled Core ML bundles; corrected encoder set is about 632 MB | Final transcription; overlapping-window provisional updates | Best fit for the native Swift and Apple-first decisions. Use only the corrected encoder. |
| sherpa-onnx | Swift wrapper over a C API and prebuilt XCFrameworks; macOS 10.15+ and iOS 15+ | INT8 ONNX package, about 640 MB installed | Offline TDT; simulated streaming requires segmentation around offline recognition | Maintained and portable, but its packaged Apple builds disable the Core ML execution provider and run this model on CPU. Better as a future cross-platform fallback. |
| NeMo-Speech.cpp | NVIDIA C ABI and CMake package; Metal release for Apple silicon | Official Q8 GGUF is about 714 MB | Full-utterance only for Parakeet TDT | Promising official runtime, but v0.1.0 is its first release. OpenYap would need to package, bridge, sign, and notarize C++ libraries without a Swift package. Revisit after its API matures. |
| MLX Audio | Python package using MLX | [SafeTensors repository](https://huggingface.co/mlx-community/parakeet-tdt-0.6b-v3) is about 2.51 GB | Final and generator-style output through Python | Useful as a reference implementation. It has no native Swift Parakeet API, so using it would require embedding Python or porting the model and decoder. |

FluidAudio v0.15.6 is Apache-2.0 and declares Swift tools 6.0, macOS 14, and iOS 17 in its [package manifest](https://github.com/FluidInference/FluidAudio/blob/v0.15.6/Package.swift). It exposes final transcription through `AsrManager`, local model loading through [`AsrModels.load(from:)`](https://github.com/FluidInference/FluidAudio/blob/07c8903b665339d880cc7eee20c7cf3d3cc19adb/Sources/FluidAudio/ASR/Parakeet/SlidingWindow/TDT/AsrModels.swift), and provisional and confirmed text through [`SlidingWindowAsrManager`](https://github.com/FluidInference/FluidAudio/blob/07c8903b665339d880cc7eee20c7cf3d3cc19adb/Sources/FluidAudio/ASR/Parakeet/SlidingWindow/SlidingWindowAsrManager.swift). Its [manual loading guide](https://github.com/FluidInference/FluidAudio/blob/07c8903b665339d880cc7eee20c7cf3d3cc19adb/Documentation/ASR/ManualModelLoading.md) supports files staged by the host app.

The strongest caution is upstream model quality. FluidAudio's [encoder investigation](https://github.com/FluidInference/FluidAudio/pull/872) reproduced silent word corruption in the former default "int8" encoder and in the int4 encoder. The replacement `Encoder_v2.mlmodelc` uses linear INT8 quantization and the new `.int8V2` selection. This correction is eight commits after v0.15.6 and has not yet shipped in a tagged release. Do not expose the older default or int4 conversion in OpenYap's catalog.

[sherpa-onnx v1.13.7](https://github.com/k2-fsa/sherpa-onnx/releases/tag/v1.13.7) is Apache-2.0 and provides a [Swift package](https://github.com/k2-fsa/sherpa-onnx/blob/v1.13.7/Package.swift) with prebuilt libraries. Its official [Parakeet instructions](https://k2-fsa.github.io/sherpa/onnx/pretrained_models/offline-transducer/nemo-transducer-models.html) include v3 INT8. The project's [Apple arm64 build preset](https://github.com/k2-fsa/sherpa-onnx/blob/6f5327bad87a18ee7dec59b9d3a2b10435189cf3/cmake/onnxruntime-osx-arm64-static.cmake) defines `SHERPA_ONNX_DISABLE_COREML`, so this path does not use the Apple Neural Engine. It remains the best evaluated option if OpenYap later needs the same ONNX runtime across Apple, Windows, and Linux.

[NeMo-Speech.cpp v0.1.0](https://github.com/NVIDIA/NeMo-Speech.cpp/releases/tag/v0.1.0) is NVIDIA's Apache-2.0 native C++ runtime. It offers a [stable C ABI](https://github.com/NVIDIA/NeMo-Speech.cpp/blob/a5b6953c4a579a2bbd1c0913ad8a85c2a4d99953/docs/sdk.md), Metal on Apple silicon, and an official Parakeet v3 GGUF. Its [model documentation](https://github.com/NVIDIA/NeMo-Speech.cpp/blob/a5b6953c4a579a2bbd1c0913ad8a85c2a4d99953/docs/asr/models.md) explicitly rejects streaming requests for Parakeet TDT. It is a credible fallback if FluidAudio fails the prototype quality gate, but adopting a first-release C++ SDK now adds avoidable packaging and Swift-bridging work.

[MLX Audio](https://github.com/Blaizzy/mlx-audio) is MIT-licensed Python software. Its [Parakeet documentation](https://github.com/Blaizzy/mlx-audio/blob/main/docs/models/stt/parakeet.md) loads MLX model repositories from Hugging Face. The native [MLX Swift](https://github.com/ml-explore/mlx-swift) project supplies tensor primitives rather than a maintained Parakeet pipeline, tokenizer, and TDT decoder. This is not a production integration route for the first native Mac prototype.

## Model choice and resources

[NVIDIA Parakeet TDT 0.6B v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3/tree/541d1f99c6b0c3cd0b11a95167540bb8edefd82b) has 600 million parameters and supports 25 European languages, including English and German. It accepts 16 kHz mono audio and provides automatic language detection, punctuation, capitalization, and timestamps in NVIDIA's implementation. Converted runtimes may expose a narrower result surface, so OpenYap should continue to own transcript preparation and formatting.

The [FluidAudio Core ML repository at revision `7dd20fe`](https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml/tree/7dd20fe6b1797d35f5e3307e8b1732d9a178edfe) contains several historical and alternate encoders. Download only these five assets:

- `Preprocessor.mlmodelc`
- `Encoder_v2.mlmodelc`
- `Decoder.mlmodelc`
- `JointDecisionv3.mlmodelc`
- `parakeet_vocab.json`

Their published byte sizes total 632,169,729 bytes, about 603 MiB. The older default set is about 461 MiB and the int4 set is about 320 MiB, but both are excluded because of the reproduced corruption. The full repository is several gigabytes and must not be cloned as one catalog item.

FluidAudio reports about 155 times real-time throughput for v3 on an M4 Pro in its [maintainer benchmarks](https://github.com/FluidInference/FluidAudio/blob/07c8903b665339d880cc7eee20c7cf3d3cc19adb/Documentation/Benchmarks.md). This is not an OpenYap measurement. No primary source publishes a reliable peak-memory figure for this Core ML path. Set the minimum hardware requirement only after testing on the oldest supported Apple silicon Mac, preferably an 8 GB M1.

Measure these values for short English and German captures, long speech, silence, noise, and accented speech:

- cold and warm model-load time
- time to first provisional text if sliding windows are enabled
- time from stop to final transcript
- peak memory, energy impact, and sustained thermal behavior
- word error rate and punctuation behavior against fixed fixtures
- failures at long capture boundaries and sliding-window seams

## Catalog and download contract

Start with a catalog compiled into the signed app. Each entry should contain:

- stable model ID and display name
- speech engine ID and pinned runtime version or commit
- Hugging Face repository and full immutable commit revision
- exact artifact path, byte size, and SHA-256 for every file
- supported languages and capabilities, including whether provisional output is available
- download size, installed size, minimum OS, and tested hardware floor
- model author, converter, source, license, attribution text, and modification notice

Resolve files with `https://huggingface.co/<repo>/resolve/<full-commit>/<path>`. Hugging Face documents revisions as branch, tag, or commit identifiers in its [download guide](https://huggingface.co/docs/huggingface_hub/guides/download). A full commit prevents the same catalog version from changing underneath an installed app.

OpenYap should own the download transaction instead of calling FluidAudio's convenience downloader. FluidAudio follows the model repository's moving `main` revision and its downloader does not verify a catalog-owned SHA-256 before accepting every existing file. The OpenYap flow should:

1. Download only the allowlisted files into a revision-specific staging directory.
2. Show progress and support cancel and retry.
3. Verify the expected byte count and SHA-256 for every artifact.
4. Reject unexpected files and any manifest mismatch.
5. Atomically promote the complete directory to `Application Support/OpenYap/Models/<model-id>/<revision>/`.
6. Load that directory with `AsrModels.load(from:version:encoderPrecision:)` and network access disabled in the runtime.
7. Keep the prior verified revision until the replacement loads successfully, then allow the user to remove either revision.

This contract also permits a future curated ONNX or GGUF entry without pretending the files are compatible with FluidAudio. Do not add arbitrary repository URLs, model code, authentication tokens, or user-imported runtimes to the first catalog.

## OpenYap integration seam

Keep capture, transcript preparation, local history, and delivery independent from a specific recognizer. Add a speech-engine interface that owns model preparation and recognition, then adapt both Apple Speech and FluidAudio behind it. The interface should expose:

- descriptor and capabilities
- installed, downloading, ready, and failed model states
- prepare, start, accept audio, finish, and cancel operations
- volatile transcript updates when supported
- one final raw transcript for the existing preparation and delivery pipeline

OpenYap should continue to own the audio session and convert captured buffers to the engine's required 16 kHz mono floating-point samples. Keep capture audio in memory and discard it after finalization, in line with [ADR 0001](../adr/0001-on-device-processing-and-local-retention.md). Do not let FluidAudio types cross into transcript history or delivery. This preserves the native-client boundary in [ADR 0004](../adr/0004-keep-native-apple-clients.md) and the transcript stages in [ADR 0003](../adr/0003-preserve-transcript-stages-in-local-history.md).

The first implementation slice should be final-on-stop only:

1. Add the speech-engine seam and keep Apple Speech behavior unchanged.
2. Add one Parakeet catalog entry pinned to the FluidAudio fix commit and model revision above.
3. Download, verify, stage, and manually load the corrected files.
4. Transcribe the completed capture, emit one final raw transcript, and pass it through the existing preparation and delivery pipeline.
5. Run the quality and resource fixtures. Add sliding-window provisional text only if the measured first-update delay and seams are acceptable.

## License and distribution

FluidAudio, sherpa-onnx, and NeMo-Speech.cpp use Apache-2.0 for their code. Preserve their licenses, notices, and bundled third-party notices in the app distribution. The NVIDIA v3 weights are [CC BY 4.0](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3/blob/541d1f99c6b0c3cd0b11a95167540bb8edefd82b/README.md). The converted FluidAudio model card declares CC BY 4.0 in its metadata but also says Apache-2.0 in its body. Treat the model artifacts as CC BY 4.0 unless the rights holders publish a clear correction.

CC BY 4.0 permits commercial use and adaptation, subject to attribution and the other [license conditions](https://creativecommons.org/licenses/by/4.0/legalcode). Credit NVIDIA as the model author, link the source and license, credit FluidInference's Core ML conversion, preserve supplied notices, and state whether OpenYap mirrored or modified the artifacts. This is a conservative compliance reading, not legal advice.

Apple documents [downloading and compiling Core ML models after installation](https://developer.apple.com/documentation/coreml/downloading-and-compiling-a-model-on-the-user-s-device). Store model data under Application Support instead of the signed app bundle. Download only model data, never executable plug-ins or runtime libraries.

OpenYap currently enables hardened runtime and disables App Sandbox in `project.yml`. A future Mac App Store build must enable App Sandbox, retain microphone access, and add the [outgoing network client entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.network.client) for model downloads. Any FluidAudio or alternate runtime binaries shipped inside the app must be signed with the app and included in notarization.

## Prototype acceptance gate

Proceed with FluidAudio if the corrected model passes the English and German accuracy fixtures, fits the measured memory and thermal budget on the minimum Mac, and produces an acceptable stop-to-final delay. Block release if the prototype must use the corrupted encoders, if its pinned artifacts cannot be reproduced and verified, or if upstream has not issued a tagged release containing the correction.

If FluidAudio fails that gate, evaluate NeMo-Speech.cpp's official Metal and GGUF path next. Use sherpa-onnx when cross-platform reuse becomes a concrete requirement. Neither fallback changes the catalog, integrity, attribution, or speech-engine boundaries above.

## Sources and inspected versions

- FluidAudio: current commit [`07c8903b665339d880cc7eee20c7cf3d3cc19adb`](https://github.com/FluidInference/FluidAudio/tree/07c8903b665339d880cc7eee20c7cf3d3cc19adb); latest release v0.15.6 at commit `4dbf4f9f9a5ff3a53ade848d7ba4e3df13db859b`; inspected 2026-09-09.
- FluidAudio Core ML model: revision [`7dd20fe6b1797d35f5e3307e8b1732d9a178edfe`](https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml/tree/7dd20fe6b1797d35f5e3307e8b1732d9a178edfe); inspected 2026-09-09.
- NVIDIA Parakeet TDT 0.6B v3: revision [`541d1f99c6b0c3cd0b11a95167540bb8edefd82b`](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3/tree/541d1f99c6b0c3cd0b11a95167540bb8edefd82b); inspected 2026-09-09.
- sherpa-onnx: current commit [`6f5327bad87a18ee7dec59b9d3a2b10435189cf3`](https://github.com/k2-fsa/sherpa-onnx/tree/6f5327bad87a18ee7dec59b9d3a2b10435189cf3); latest release v1.13.7 at commit `917bed95c8e5c7c18aa4d69fea42e9ef8ef0a60e`; inspected 2026-09-09.
- NeMo-Speech.cpp: current commit [`a5b6953c4a579a2bbd1c0913ad8a85c2a4d99953`](https://github.com/NVIDIA/NeMo-Speech.cpp/tree/a5b6953c4a579a2bbd1c0913ad8a85c2a4d99953); latest release v0.1.0 at commit `4f9676226f667d14608487df744f375db87127f8`; inspected 2026-09-09.
