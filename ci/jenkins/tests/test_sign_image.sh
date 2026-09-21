#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/assert.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

SCRIPT_PATH="$REPO_ROOT/ci/jenkins/scripts/sign_image.sh"
POLICY_PATH="$REPO_ROOT/custom/system-files/etc/containers/policy.json"
REGISTRIES_PATH="$REPO_ROOT/custom/system-files/etc/containers/registries.d/bluefin.yaml"

DIGEST="sha256:$(printf 'a%.0s' {1..64})"
VALID_REFERENCE="ghcr.io/ericrocha97/bluefin-cosmic-dx@${DIGEST}"

mkdir -p "$TMPDIR/bin"
COSIGN_CALLS_FILE="$TMPDIR/cosign-calls.txt"
# The mock records one argument per line and terminates every invocation with a
# marker line. This preserves argument boundaries and keeps the ordered argv of
# each call (sign, then verify) separable instead of a lossy space-joined blob.
cat >"$TMPDIR/bin/cosign" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
{
    printf '%s\n' "$@"
    printf '%s\n' '===COSIGN_CALL_END==='
} >> "$COSIGN_CALLS_FILE"
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

# Number of recorded cosign invocations (sign + verify count separately).
cosign_call_count() {
    if [[ ! -f "$COSIGN_CALLS_FILE" ]]; then
        printf '0\n'
        return 0
    fi
    grep -cF '===COSIGN_CALL_END===' "$COSIGN_CALLS_FILE" || true
}

# Return the argv of the Nth (1-based) invocation, one argument per line.
cosign_argv() {
    local index="$1"
    awk -v target="$index" '
        $0 == "===COSIGN_CALL_END===" { call++; next }
        call == target - 1 { print }
    ' "$COSIGN_CALLS_FILE"
}

# Assert the exact, ordered argv recorded for a single cosign invocation.
assert_cosign_argv() {
    local index="$1"
    shift
    local expected actual
    expected="$(printf '%s\n' "$@")"
    actual="$(cosign_argv "$index")"
    if [[ "$expected" != "$actual" ]]; then
        printf 'EXPECTED invocation %s argv:\n%s\nACTUAL argv:\n%s\n' "$index" "$expected" "$actual" >&2
        fail "cosign invocation $index argv mismatch"
    fi
}

assert_call_count() {
    local expected="$1" actual
    actual="$(cosign_call_count)"
    if [[ "$expected" != "$actual" ]]; then
        fail "expected $expected cosign invocation(s), got $actual"
    fi
}

export COSIGN_KEY_FILE="$KEY_FILE"
export COSIGN_PASSWORD="test-password"

# Valid digest reference: cosign signs the legacy bundle format, then verifies
# the same digest against the versioned public key.
rm -f "$COSIGN_CALLS_FILE"
bash "$SCRIPT_PATH" "$VALID_REFERENCE"

assert_call_count 2
assert_cosign_argv 1 sign \
    --yes \
    --new-bundle-format=false \
    --use-signing-config=false \
    --key "$COSIGN_KEY_FILE" \
    -- "$VALID_REFERENCE"
assert_cosign_argv 2 verify \
    --new-bundle-format=false \
    --key cosign.pub \
    -- "$VALID_REFERENCE"
assert_file_not_contains "$COSIGN_CALLS_FILE" "$COSIGN_PASSWORD"

# A digest reference beginning with '-' must not be interpreted as a cosign
# option: it stays a single positional argument after `--` for both sign and
# verify.
INJECTION_REFERENCE="--registry-mirror=evil@${DIGEST}"
rm -f "$COSIGN_CALLS_FILE"
bash "$SCRIPT_PATH" "$INJECTION_REFERENCE"

assert_call_count 2
assert_cosign_argv 1 sign \
    --yes \
    --new-bundle-format=false \
    --use-signing-config=false \
    --key "$COSIGN_KEY_FILE" \
    -- "$INJECTION_REFERENCE"
assert_cosign_argv 2 verify \
    --new-bundle-format=false \
    --key cosign.pub \
    -- "$INJECTION_REFERENCE"

# Cosign failures must propagate (non-zero exit and preserved stderr), and a
# failed sign must not reach the verify step.
rm -f "$COSIGN_CALLS_FILE"
export COSIGN_MOCK_FAIL=1
if bash "$SCRIPT_PATH" "$VALID_REFERENCE" 2>"$TMPDIR/cosign-failure.err"; then
    fail "cosign failure must propagate as a non-zero exit"
fi
assert_call_count 1
assert_cosign_argv 1 sign \
    --yes \
    --new-bundle-format=false \
    --use-signing-config=false \
    --key "$COSIGN_KEY_FILE" \
    -- "$VALID_REFERENCE"
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

# The private key is never versioned: only the injected COSIGN_KEY_FILE path is
# consumed and cosign.key is gitignored. Check Git tracking rather than the
# filesystem, so a maintainer's local, ignored cosign.key (created by
# `cosign generate-key-pair`) does not fail the suite.
tracked_private_key="$(git -C "$REPO_ROOT" ls-files -- cosign.key 2>/dev/null || true)"
if [[ -n "$tracked_private_key" ]]; then
    fail "cosign.key must not be tracked by Git"
fi
assert_file_contains "$REPO_ROOT/.gitignore" "cosign.key"
assert_file_not_contains "$SCRIPT_PATH" "cosign.key"

# The strict bootc/containers-image signature policy must not be weakened.
assert_file_contains "$POLICY_PATH" '"type": "sigstoreSigned"'
assert_file_contains "$POLICY_PATH" '"keyPath": "/etc/pki/containers/cosign.pub"'
assert_file_not_contains "$POLICY_PATH" "insecureAcceptAnything"
assert_file_contains "$REGISTRIES_PATH" "use-sigstore-attachments: true"

printf 'PASS: test_sign_image.sh\n'
