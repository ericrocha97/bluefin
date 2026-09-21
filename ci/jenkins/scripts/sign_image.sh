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

# Cosign 3.x defaults to the new Sigstore bundle format (OCI 1.1 referrers),
# which the containers/image `sigstoreSigned` policy used by bootc/rpm-ostree
# cannot consume. `--new-bundle-format=false` restores the legacy OCI
# attachment (`<digest>.sig`) that containers/image looks up when
# `use-sigstore-attachments: true` is configured in registries.d.
# `--use-signing-config=false` skips the TUF-provided signing config so the
# key-based flow behaves like pre-3.x Cosign.
#
# The `--` option terminator keeps a reference that starts with '-' from being
# parsed as a cosign flag. Cosign is built on Cobra, which treats everything
# after `--` as positional arguments (verified against cosign v3.1.3).
cosign sign \
    --yes \
    --new-bundle-format=false \
    --use-signing-config=false \
    --key "$COSIGN_KEY_FILE" \
    -- "$image_reference"

# Verify the signature that was just published, from the same digest reference
# and against the public key versioned in this repository. With
# `set -euo pipefail`, a verification failure aborts the pipeline before the
# `stable` tag is promoted.
echo "Verifying published signature..."

cosign verify \
    --new-bundle-format=false \
    --key cosign.pub \
    -- "$image_reference"
