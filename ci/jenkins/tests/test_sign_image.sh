#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/assert.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

SCRIPT_PATH="$REPO_ROOT/ci/jenkins/scripts/sign_image.sh"

DIGEST="sha256:$(printf 'a%.0s' {1..64})"
VALID_REFERENCE="ghcr.io/ericrocha97/bluefin-cosmic-dx@${DIGEST}"

mkdir -p "$TMPDIR/bin"
COSIGN_CALLS_FILE="$TMPDIR/cosign-calls.txt"
# The mock records one argument per line so argument boundaries are preserved.
# This lets the tests assert the exact ordered argv, including the `--`
# option separator, instead of a lossy space-joined string.
cat >"$TMPDIR/bin/cosign" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" >> "$COSIGN_CALLS_FILE"
if [[ -n "${COSIGN_MOCK_FAIL:-}" ]]; then
    printf 'mock cosign failure\n' >&2
    exit "${COSIGN_MOCK_EXIT_CODE:-1}"
fi
EOF
chmod +x "$TMPDIR/bin/cosign"

export PATH="$TMPDIR/bin:$PATH"
export COSIGN_CALLS_FILE

KEY_FILE="$TMPDIR/cosign.key"
printf 'dummy-key-material\n' >"$KEY_FILE"

assert_no_cosign_call() {
    if [[ -f "$COSIGN_CALLS_FILE" ]]; then
        fail "cosign must not be called: $1"
    fi
}

# Assert the exact, ordered argv recorded for a single cosign invocation.
assert_cosign_argv() {
    local expected actual
    expected="$(printf '%s\n' "$@")"
    actual="$(cat "$COSIGN_CALLS_FILE")"
    if [[ "$expected" != "$actual" ]]; then
        printf 'EXPECTED argv:\n%s\nACTUAL argv:\n%s\n' "$expected" "$actual" >&2
        fail "cosign argv mismatch"
    fi
}

export COSIGN_KEY_FILE="$KEY_FILE"
export COSIGN_PASSWORD="test-password"

# Valid digest reference: cosign receives the key path and the reference after a
# `--` option terminator, as separate positional arguments.
rm -f "$COSIGN_CALLS_FILE"
bash "$SCRIPT_PATH" "$VALID_REFERENCE"

assert_cosign_argv sign --yes --key "$COSIGN_KEY_FILE" -- "$VALID_REFERENCE"
assert_file_not_contains "$COSIGN_CALLS_FILE" "$COSIGN_PASSWORD"

# A digest reference beginning with '-' must not be interpreted as a cosign
# option: it stays a single positional argument after `--`.
INJECTION_REFERENCE="--registry-mirror=evil@${DIGEST}"
rm -f "$COSIGN_CALLS_FILE"
bash "$SCRIPT_PATH" "$INJECTION_REFERENCE"

assert_cosign_argv sign --yes --key "$COSIGN_KEY_FILE" -- "$INJECTION_REFERENCE"

# Cosign failures must propagate (non-zero exit and preserved stderr).
rm -f "$COSIGN_CALLS_FILE"
export COSIGN_MOCK_FAIL=1
if bash "$SCRIPT_PATH" "$VALID_REFERENCE" 2>"$TMPDIR/cosign-failure.err"; then
    fail "cosign failure must propagate as a non-zero exit"
fi
assert_cosign_argv sign --yes --key "$COSIGN_KEY_FILE" -- "$VALID_REFERENCE"
assert_file_contains "$TMPDIR/cosign-failure.err" "mock cosign failure"
unset COSIGN_MOCK_FAIL

# Missing digest: a tag-only reference must be rejected before calling cosign.
rm -f "$COSIGN_CALLS_FILE"
if bash "$SCRIPT_PATH" "ghcr.io/ericrocha97/bluefin-cosmic-dx:stable" 2>"$TMPDIR/missing-digest.err"; then
    fail "Reference without @sha256: must fail"
fi
assert_no_cosign_call "reference without digest was rejected"

# Malformed digest: wrong hex length must be rejected before calling cosign.
SHORT_DIGEST="sha256:$(printf 'a%.0s' {1..63})"
rm -f "$COSIGN_CALLS_FILE"
if bash "$SCRIPT_PATH" "ghcr.io/ericrocha97/bluefin-cosmic-dx@${SHORT_DIGEST}" 2>"$TMPDIR/short-digest.err"; then
    fail "Reference with a short digest must fail"
fi
assert_no_cosign_call "reference with a short digest was rejected"

# Missing reference: the script must require an argument.
rm -f "$COSIGN_CALLS_FILE"
if bash "$SCRIPT_PATH" 2>"$TMPDIR/missing-reference.err"; then
    fail "Missing image reference must fail"
fi
assert_no_cosign_call "missing reference was rejected"

# Missing key: COSIGN_KEY_FILE must be required.
rm -f "$COSIGN_CALLS_FILE"
unset COSIGN_KEY_FILE
if bash "$SCRIPT_PATH" "$VALID_REFERENCE" 2>"$TMPDIR/missing-key.err"; then
    fail "Missing COSIGN_KEY_FILE must fail"
fi
assert_no_cosign_call "missing key was rejected"

# Missing password: COSIGN_PASSWORD must be required.
export COSIGN_KEY_FILE="$KEY_FILE"
unset COSIGN_PASSWORD
if bash "$SCRIPT_PATH" "$VALID_REFERENCE" 2>"$TMPDIR/missing-password.err"; then
    fail "Missing COSIGN_PASSWORD must fail"
fi
assert_no_cosign_call "missing password was rejected"

printf 'PASS: test_sign_image.sh\n'
