#!/bin/bash
set -euo pipefail

prototype_dir="$(cd "$(dirname "$0")" && pwd)"
cache_dir="${OPENYAP_PARAKEET_CACHE:-$prototype_dir/.prototype-cache}"
fixture_dir="$cache_dir/fixtures"
result_dir="$cache_dir/results"

mkdir -p "$fixture_dir" "$result_dir"

english_text="OpenYap keeps dictation private and processes speech locally on this Mac."
german_text="OpenYap verarbeitet Diktate privat und lokal auf diesem Mac."
long_text="OpenYap keeps dictation private. The completed capture stays in memory until transcription finishes. The raw transcript then enters text preparation, history, and delivery. This sentence repeats to exercise a longer final-on-stop capture."

say -v Samantha -o "$fixture_dir/english.aiff" "$english_text"
say -v Anna -o "$fixture_dir/german.aiff" "$german_text"
say -v Samantha -r 185 -o "$fixture_dir/long.aiff" "$long_text $long_text $long_text $long_text $long_text"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
swift build --package-path "$prototype_dir" -c release
binary="$(swift build --package-path "$prototype_dir" -c release --show-bin-path)/ParakeetFinalOnStop"
model_dir="$($prototype_dir/download-model.sh)"

run_fixture() {
    local name="$1"
    local locale="$2"
    local reference="$3"
    "$binary" \
        --audio "$fixture_dir/$name" \
        --model-dir "$model_dir" \
        --locale "$locale" \
        --reference "$reference" \
        --output "$result_dir/$name.json"
}

run_fixture english.aiff en-US "$english_text"
run_fixture german.aiff de-DE "$german_text"
run_fixture long.aiff en-US "$long_text $long_text $long_text $long_text $long_text"

if command -v ffmpeg >/dev/null 2>&1; then
    ffmpeg -hide_banner -loglevel error -y -f lavfi -i anullsrc=r=16000:cl=mono -t 5 "$fixture_dir/silence.wav"
    run_fixture silence.wav en-US "" || true
else
    printf 'Skipping silence fixture because ffmpeg is unavailable.\n' >&2
fi

"$binary" \
    --audio "$fixture_dir/long.aiff" \
    --model-dir "$model_dir" \
    --locale en-US \
    --reference "$long_text $long_text $long_text $long_text $long_text" \
    --cancel-after-ms 10 \
    --output "$result_dir/cancellation.json" || true

printf '\nReports: %s\n' "$result_dir"
