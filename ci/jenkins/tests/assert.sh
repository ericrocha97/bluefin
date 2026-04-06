#!/usr/bin/env bash

set -euo pipefail

fail() {
    local message="$1"
    printf 'ASSERTION FAILED: %s\n' "$message" >&2
    exit 1
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [[ "$expected" != "$actual" ]]; then
        fail "$message"
    fi
}

assert_file_contains() {
    local file_path="$1"
    local expected_text="$2"

    if [[ ! -f "$file_path" ]]; then
        fail "File does not exist: $file_path"
    fi

    if ! grep -Fq -- "$expected_text" "$file_path"; then
        fail "Expected '$expected_text' in $file_path"
    fi
}

assert_contains() {
    local actual_text="$1"
    local expected_text="$2"

    if [[ "$actual_text" != *"$expected_text"* ]]; then
        fail "Expected '$expected_text' in provided text"
    fi
}
