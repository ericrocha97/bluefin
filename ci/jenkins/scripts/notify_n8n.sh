#!/usr/bin/env bash

set -euo pipefail

: "${STATUS:?STATUS is required}"
: "${JOB_NAME:?JOB_NAME is required}"
: "${BUILD_NUMBER:?BUILD_NUMBER is required}"
: "${BUILD_URL:?BUILD_URL is required}"
: "${GIT_SHA:?GIT_SHA is required}"
: "${IMAGE_NAME:?IMAGE_NAME is required}"
: "${PUBLISHED_TAGS:=}"
: "${TIMESTAMP_UTC:?TIMESTAMP_UTC is required}"
: "${STARTED_AT:?STARTED_AT is required}"
: "${FINISHED_AT:?FINISHED_AT is required}"
: "${DURATION_MS:?DURATION_MS is required}"
: "${RELEASE_TAG:?RELEASE_TAG is required}"

error_summary="${ERROR_SUMMARY:-}"
dry_run="${DRY_RUN:-false}"
curl_connect_timeout="${N8N_NOTIFY_CONNECT_TIMEOUT_SECONDS:-5}"
curl_max_time="${N8N_NOTIFY_MAX_TIME_SECONDS:-30}"
curl_retry_count="${N8N_NOTIFY_RETRY_COUNT:-3}"
curl_retry_delay="${N8N_NOTIFY_RETRY_DELAY_SECONDS:-2}"

json_escape() {
    local value="$1"

    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\n'/\\n}
    value=${value//$'\r'/\\r}
    value=${value//$'\t'/\\t}

    printf '%s' "$value"
}

build_published_tags_json() {
    local raw_tags="$1"
    local tags_json=""
    local item=""
    local trimmed=""

    IFS=',' read -r -a tags_array <<<"$raw_tags"
    for item in "${tags_array[@]}"; do
        trimmed="${item#"${item%%[![:space:]]*}"}"
        trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
        if [[ -z "$trimmed" ]]; then
            continue
        fi

        if [[ -n "$tags_json" ]]; then
            tags_json+=","
        fi
        tags_json+="\"$(json_escape "$trimmed")\""
    done

    printf '[%s]' "$tags_json"
}

published_tags_json="$(build_published_tags_json "$PUBLISHED_TAGS")"

payload=$(cat <<EOF
{"status":"$(json_escape "$STATUS")","job_name":"$(json_escape "$JOB_NAME")","build_number":"$(json_escape "$BUILD_NUMBER")","build_url":"$(json_escape "$BUILD_URL")","git_sha":"$(json_escape "$GIT_SHA")","image_name":"$(json_escape "$IMAGE_NAME")","published_tags":$published_tags_json,"timestamp_utc":"$(json_escape "$TIMESTAMP_UTC")","error_summary":"$(json_escape "$error_summary")","started_at":"$(json_escape "$STARTED_AT")","finished_at":"$(json_escape "$FINISHED_AT")","duration_ms":"$(json_escape "$DURATION_MS")","release_tag":"$(json_escape "$RELEASE_TAG")"}
EOF
)

if [[ -n "${OUTPUT_PAYLOAD_FILE:-}" ]]; then
    printf '%s' "$payload" >"$OUTPUT_PAYLOAD_FILE"
fi

if [[ "$dry_run" == "true" ]]; then
    printf '%s\n' "$payload"
    exit 0
fi

: "${WEBHOOK_URL:?WEBHOOK_URL is required when DRY_RUN is not true}"
: "${N8N_WEBHOOK_SHARED_TOKEN:?N8N_WEBHOOK_SHARED_TOKEN is required when DRY_RUN is not true}"

if [[ "$WEBHOOK_URL" == *"localhost"* || "$WEBHOOK_URL" == *"127.0.0.1"* ]]; then
    echo "WARN: WEBHOOK_URL points to localhost/127.0.0.1. This resolves inside the Jenkins runtime and can fail if n8n is external." >&2
fi

printf '%s' "$payload" | curl --silent --show-error --fail \
    --connect-timeout "$curl_connect_timeout" \
    --max-time "$curl_max_time" \
    --retry "$curl_retry_count" \
    --retry-delay "$curl_retry_delay" \
    --retry-all-errors \
    --request POST \
    --header "Content-Type: application/json" \
    --header "x-jenkins-webhook-token: $N8N_WEBHOOK_SHARED_TOKEN" \
    --data-binary @- \
    --url "$WEBHOOK_URL"
