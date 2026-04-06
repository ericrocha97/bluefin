#!/usr/bin/env bash

set -euo pipefail

: "${IMAGE_NAME:?IMAGE_NAME is required}"
: "${BUILD_DATE:?BUILD_DATE is required}"
: "${VERSION_DATE:?VERSION_DATE is required}"
: "${TAGS_FILE:?TAGS_FILE is required}"
: "${LABELS_FILE:?LABELS_FILE is required}"

printf 'stable\nstable.%s\n%s\n' "$VERSION_DATE" "$VERSION_DATE" >"$TAGS_FILE"

printf '%s\n' \
    "org.opencontainers.image.created=$BUILD_DATE" \
    "org.opencontainers.image.title=$IMAGE_NAME" \
    "containers.bootc=1" >"$LABELS_FILE"
