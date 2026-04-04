#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# shellcheck source=ci/jenkins/tests/assert.sh
source "$SCRIPT_DIR/assert.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

TAGS_FILE="$TMPDIR/tags.txt"
LABELS_FILE="$TMPDIR/labels.txt"

export IMAGE_NAME="bluefin-cosmic-dx"
export BUILD_DATE="2026-04-03T10:05:00Z"
export VERSION_DATE="20260403"
export TAGS_FILE
export LABELS_FILE

bash "$REPO_ROOT/ci/jenkins/scripts/generate_metadata.sh"

expected_tags=$'stable\nstable.20260403\n20260403\n'
actual_tags="$(<"$TAGS_FILE")"
actual_tags+=$'\n'
assert_equals "$expected_tags" "$actual_tags" "Tags file should exactly match expected content"

assert_file_contains "$LABELS_FILE" "org.opencontainers.image.created=2026-04-03T10:05:00Z"
assert_file_contains "$LABELS_FILE" "org.opencontainers.image.title=bluefin-cosmic-dx"
assert_file_contains "$LABELS_FILE" "containers.bootc=1"

printf 'PASS: test_generate_metadata.sh\n'
