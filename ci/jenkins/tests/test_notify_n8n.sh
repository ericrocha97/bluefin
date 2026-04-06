#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/assert.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

SCRIPT_PATH="$REPO_ROOT/ci/jenkins/scripts/notify_n8n.sh"

base_env() {
    export STATUS="success"
    export JOB_NAME="bluefin-build"
    export BUILD_NUMBER="123"
    export BUILD_URL="https://jenkins.example/job/123"
    export GIT_SHA="0123456789abcdef"
    export IMAGE_NAME="ghcr.io/example/bluefin-cosmic-dx"
    export PUBLISHED_TAGS="stable,stable.20260403,20260403"
    export TIMESTAMP_UTC="2026-04-03T13:30:00Z"
    export ERROR_SUMMARY=""
    export STARTED_AT="2026-04-03T13:00:00Z"
    export FINISHED_AT="2026-04-03T13:30:00Z"
    export DURATION_MS="1800000"
    export RELEASE_TAG="v20260403"
}

base_env

export OUTPUT_PAYLOAD_FILE="$TMPDIR/payload.json"
export DRY_RUN="true"
export WEBHOOK_URL="https://n8n.example/webhook/build"
export N8N_WEBHOOK_SHARED_TOKEN="test-shared-token"
dry_run_output="$(bash "$SCRIPT_PATH")"

assert_file_contains "$OUTPUT_PAYLOAD_FILE" '"status":"success"'
assert_file_contains "$OUTPUT_PAYLOAD_FILE" '"job_name":"bluefin-build"'
assert_file_contains "$OUTPUT_PAYLOAD_FILE" '"published_tags":["stable","stable.20260403","20260403"]'
assert_file_contains "$OUTPUT_PAYLOAD_FILE" '"release_tag":"v20260403"'
assert_file_contains "$OUTPUT_PAYLOAD_FILE" '"error_summary":""'
assert_file_contains "$OUTPUT_PAYLOAD_FILE" '"duration_ms":"1800000"'
assert_file_contains "$OUTPUT_PAYLOAD_FILE" '"started_at":"2026-04-03T13:00:00Z"'
assert_file_contains "$OUTPUT_PAYLOAD_FILE" '"finished_at":"2026-04-03T13:30:00Z"'

assert_equals "$(<"$OUTPUT_PAYLOAD_FILE")" "$dry_run_output" "DRY_RUN should print payload and skip webhook"

mkdir -p "$TMPDIR/bin"
cat >"$TMPDIR/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" > "$CURL_ARGS_FILE"
cat > "$CURL_BODY_FILE"
EOF
chmod +x "$TMPDIR/bin/curl"

export PATH="$TMPDIR/bin:$PATH"
export CURL_ARGS_FILE="$TMPDIR/curl-args.txt"
export CURL_BODY_FILE="$TMPDIR/curl-body.json"
export DRY_RUN="false"
unset OUTPUT_PAYLOAD_FILE

bash "$SCRIPT_PATH"

assert_file_contains "$CURL_ARGS_FILE" 'request POST'
assert_file_contains "$CURL_ARGS_FILE" 'header Content-Type: application/json'
assert_file_contains "$CURL_ARGS_FILE" 'header x-jenkins-webhook-token: test-shared-token'
assert_file_contains "$CURL_ARGS_FILE" 'connect-timeout 5'
assert_file_contains "$CURL_ARGS_FILE" 'max-time 30'
assert_file_contains "$CURL_ARGS_FILE" 'retry 3'
assert_file_contains "$CURL_ARGS_FILE" 'retry-delay 2'
assert_file_contains "$CURL_ARGS_FILE" 'retry-all-errors'
assert_file_contains "$CURL_ARGS_FILE" 'url https://n8n.example/webhook/build'
assert_file_contains "$CURL_BODY_FILE" '"git_sha":"0123456789abcdef"'
assert_file_contains "$CURL_BODY_FILE" '"image_name":"ghcr.io/example/bluefin-cosmic-dx"'
assert_file_contains "$CURL_BODY_FILE" '"timestamp_utc":"2026-04-03T13:30:00Z"'

unset WEBHOOK_URL
if bash "$SCRIPT_PATH" >/dev/null 2>&1; then
    fail "Script should fail when WEBHOOK_URL is missing and DRY_RUN is false"
fi

export WEBHOOK_URL="https://n8n.example/webhook/build"
unset N8N_WEBHOOK_SHARED_TOKEN
if bash "$SCRIPT_PATH" >/dev/null 2>&1; then
    fail "Script should fail when N8N_WEBHOOK_SHARED_TOKEN is missing and DRY_RUN is false"
fi

printf 'PASS: test_notify_n8n.sh\n'
