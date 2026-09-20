#!/usr/bin/env bash

set -euo pipefail

image_reference="${1:-}"

: "${image_reference:?image reference by digest is required}"
: "${COSIGN_KEY_FILE:?COSIGN_KEY_FILE is required}"
: "${COSIGN_PASSWORD:?COSIGN_PASSWORD is required}"

if [[ ! "$image_reference" =~ @sha256:[0-9a-f]{64}$ ]]; then
    printf 'ERROR: image reference must be pinned by digest (@sha256:<64 hex>): %s\n' "$image_reference" >&2
    exit 1
fi

# The `--` option terminator keeps a reference that starts with '-' from being
# parsed as a cosign flag. Cosign is built on Cobra, which treats everything
# after `--` as positional arguments (verified against cosign v3.1.3).
cosign sign --yes --key "$COSIGN_KEY_FILE" -- "$image_reference"
