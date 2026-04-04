#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/assert.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

SCRIPT_PATH="$REPO_ROOT/ci/jenkins/scripts/extract_versions.sh"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"

OUTPUT_FILE="$TMPDIR/output.txt"
CURRENT_MANIFEST="$FIXTURES_DIR/current-manifest.txt"
PREVIOUS_MANIFEST="$FIXTURES_DIR/previous-manifest.txt"

export CURRENT_MANIFEST PREVIOUS_MANIFEST OUTPUT_FILE
bash "$SCRIPT_PATH"

assert_file_contains "$OUTPUT_FILE" "kernel_version=6.8.12-300.fc42.x86_64"
assert_file_contains "$OUTPUT_FILE" "vscode_version=1.92.0-1722860000.el8"
assert_file_contains "$OUTPUT_FILE" "warp_version=0.2024.08.14.08.02.stable_00-1"
assert_file_contains "$OUTPUT_FILE" "vicinae_version=0.5.2-1"
assert_file_contains "$OUTPUT_FILE" "cosmic_session_version=1.0.0~alpha.7-1"
assert_file_contains "$OUTPUT_FILE" "code-insiders: 1.91.0-1722000000.el8 -> 1.92.0-1722860000.el8"
assert_file_contains "$OUTPUT_FILE" "warp-terminal: 0.2024.08.01.08.02.stable_00-1 -> 0.2024.08.14.08.02.stable_00-1"
assert_file_contains "$OUTPUT_FILE" "vicinae: 0.5.1-1 -> 0.5.2-1"
assert_file_contains "$OUTPUT_FILE" "cosmic-session: 1.0.0~alpha.6-1 -> 1.0.0~alpha.7-1"

NO_CHANGES_OUTPUT_FILE="$TMPDIR/no-changes-output.txt"
export OUTPUT_FILE="$NO_CHANGES_OUTPUT_FILE"
export PREVIOUS_MANIFEST="$FIXTURES_DIR/current-manifest.txt"
bash "$SCRIPT_PATH"

assert_file_contains "$NO_CHANGES_OUTPUT_FILE" "No tracked package version changes detected."

printf 'PASS: test_extract_versions.sh\n'
