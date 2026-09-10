# Final-on-stop Parakeet prototype

This is throwaway code for the question in [Prototype final-on-stop Parakeet transcription](https://github.com/pabumake/openyap/issues/15). It does not belong on `main`.

The executable reads a completed audio file into 16 kHz mono memory, releases the capture owner's copy when finalization starts, and sends the samples through a small `FinalOnStopSpeechEngine` interface. The FluidAudio adapter emits one raw transcript. A boundary probe then checks that formatting, history, and delivery remain downstream and receive no FluidAudio type.

The prototype pins:

- FluidAudio commit `c7246f4dc78d05f75cdfc5a550cd72ced0c658bf`
- model revision `7dd20fe6b1797d35f5e3307e8b1732d9a178edfe`
- corrected `Encoder_v2.mlmodelc` through FluidAudio's `int8-v2` option

## Run the smoke suite

From the repository root:

```sh
./Prototypes/ParakeetFinalOnStop/run-smoke.sh
```

The first run downloads and verifies about 603 MiB of model files. The suite generates English, German, long-capture, and silence fixtures in the ignored `.prototype-cache` directory. It writes one JSON report per fixture. Run it twice to compare cold and warm model-load times.

The generated voices are wiring checks, not a product-quality accuracy corpus. Replace them with fixed human recordings and matching `--reference` text before setting a release gate.

## Run one capture

```sh
swift run --package-path Prototypes/ParakeetFinalOnStop -c release ParakeetFinalOnStop \
  --audio /path/to/capture.wav \
  --model-dir Prototypes/ParakeetFinalOnStop/.prototype-cache/models/parakeet-tdt-0.6b-v3-coreml \
  --locale de-DE \
  --reference "Die erwartete Transkription" \
  --output /tmp/parakeet-result.json
```

Add `--cancel-after-ms 100` to probe cancellation during finalization. A cancelled run must not produce raw transcript, history, or delivery stages.

## Measure energy

The macOS 26 Instruments CLI lists `Power Profiler`, but it rejects that template on a Mac and says it supports iOS and iPadOS only. Use `powermetrics` around a representative long run instead. It requires an administrator at the terminal, so the automated smoke suite leaves energy unmeasured.

```sh
sudo powermetrics \
  --sample-rate 100 \
  --sample-count 50 \
  --samplers cpu_power,gpu_power,ane_power,tasks \
  --show-process-energy \
  --output-file /tmp/openyap-parakeet-power.txt
```

Start the long prototype run in a second terminal while `powermetrics` samples. Peak resident memory, package bytes, audio duration, load time, stop-to-final time, stop-to-terminal time, FluidAudio processing time, RTFx, confidence, transcript text, WER, lifecycle trace, cancellation, and retained capture samples are recorded in each JSON report.
