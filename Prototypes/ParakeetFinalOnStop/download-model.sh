#!/bin/bash
set -euo pipefail

prototype_dir="$(cd "$(dirname "$0")" && pwd)"
cache_dir="${OPENYAP_PARAKEET_CACHE:-$prototype_dir/.prototype-cache}"
model_revision="7dd20fe6b1797d35f5e3307e8b1732d9a178edfe"
model_repo="FluidInference/parakeet-tdt-0.6b-v3-coreml"
model_dir="$cache_dir/models/parakeet-tdt-0.6b-v3-coreml"
manifest="$prototype_dir/model-manifest.tsv"

hash_file() {
    local path="$1"
    local kind="$2"
    if [[ "$kind" == "sha256" ]]; then
        shasum -a 256 "$path" | awk '{print $1}'
    else
        git hash-object "$path"
    fi
}

validate_model() {
    local root="$1"
    local relative size kind expected target actual_size actual_hash
    while IFS=$'\t' read -r relative size kind expected; do
        [[ -z "$relative" || "$relative" == \#* ]] && continue
        target="$root/$relative"
        [[ -f "$target" ]] || return 1
        actual_size="$(stat -f '%z' "$target")"
        [[ "$actual_size" == "$size" ]] || return 1
        actual_hash="$(hash_file "$target" "$kind")"
        [[ "$actual_hash" == "$expected" ]] || return 1
    done < "$manifest"
}

if validate_model "$model_dir"; then
    printf '%s\n' "$model_dir"
    exit 0
fi

mkdir -p "$cache_dir/models"
stage="$(mktemp -d "$cache_dir/model-staging.XXXXXX")"
failed_stage="$stage.failed"

cleanup_on_failure() {
    if [[ -d "$stage" ]]; then
        mv "$stage" "$failed_stage"
        printf 'Download failed. Partial files remain at %s\n' "$failed_stage" >&2
    fi
}
trap cleanup_on_failure ERR INT TERM

printf 'Downloading the pinned Parakeet package, about 603 MiB...\n' >&2
while IFS=$'\t' read -r relative size kind expected; do
    [[ -z "$relative" || "$relative" == \#* ]] && continue
    target="$stage/$relative"
    mkdir -p "$(dirname "$target")"
    url="https://huggingface.co/$model_repo/resolve/$model_revision/$relative"
    printf '  %s\n' "$relative" >&2
    curl --fail --location --retry 3 --continue-at - --output "$target" "$url"

    actual_size="$(stat -f '%z' "$target")"
    [[ "$actual_size" == "$size" ]] || {
        printf 'Size mismatch for %s: expected %s, got %s\n' "$relative" "$size" "$actual_size" >&2
        false
    }
    actual_hash="$(hash_file "$target" "$kind")"
    [[ "$actual_hash" == "$expected" ]] || {
        printf 'Hash mismatch for %s\n' "$relative" >&2
        false
    }
done < "$manifest"

if [[ -e "$model_dir" ]]; then
    mv "$model_dir" "$model_dir.invalid.$(date +%s)"
fi
mv "$stage" "$model_dir"
trap - ERR INT TERM

validate_model "$model_dir"
printf '%s\n' "$model_dir"
