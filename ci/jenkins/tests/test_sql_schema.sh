#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/assert.sh"

SQL_FILE="$REPO_ROOT/n8n/sql/001_ci_pipeline_runs.sql"

if [[ ! -f "$SQL_FILE" ]]; then
    fail "Missing SQL schema file: $SQL_FILE"
fi

assert_file_contains "$SQL_FILE" "CREATE TABLE IF NOT EXISTS ci_pipeline_runs"

if ! grep -Eq 'UNIQUE[[:space:]]*\([[:space:]]*job_name[[:space:]]*,[[:space:]]*build_number[[:space:]]*\)' "$SQL_FILE"; then
    fail "Expected unique constraint on (job_name, build_number)"
fi

if ! grep -Eq 'published_tags[[:space:]]+jsonb' "$SQL_FILE"; then
    fail "Expected jsonb column: published_tags"
fi

if ! grep -Eq 'payload[[:space:]]+jsonb' "$SQL_FILE"; then
    fail "Expected jsonb column: payload"
fi

if ! grep -Eq 'CREATE[[:space:]]+INDEX[[:space:]]+.*created_at' "$SQL_FILE"; then
    fail "Expected index for created_at"
fi

if ! grep -Eq 'CREATE[[:space:]]+INDEX[[:space:]]+.*status' "$SQL_FILE"; then
    fail "Expected index for status"
fi

printf 'PASS: test_sql_schema.sh\n'
