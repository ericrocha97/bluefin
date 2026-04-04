#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/assert.sh"

JENKINSFILE="$REPO_ROOT/Jenkinsfile"

assert_file_contains "$JENKINSFILE" "pipeline {"
assert_file_contains "$JENKINSFILE" "disableConcurrentBuilds(abortPrevious: true)"
assert_file_contains "$JENKINSFILE" "cron('H 10 * * *')"

assert_file_contains "$JENKINSFILE" "stage('Build Image')"
assert_file_contains "$JENKINSFILE" "stage('Push Docker Hub')"
assert_file_contains "$JENKINSFILE" "stage('Create GitHub Release')"

assert_file_contains "$JENKINSFILE" "post {"
assert_file_contains "$JENKINSFILE" "success {"
assert_file_contains "$JENKINSFILE" "failure {"

assert_file_contains "$JENKINSFILE" "ci/jenkins/scripts/generate_metadata.sh"
assert_file_contains "$JENKINSFILE" "ci/jenkins/scripts/extract_versions.sh"
assert_file_contains "$JENKINSFILE" "ci/jenkins/scripts/create_github_release.sh"
assert_file_contains "$JENKINSFILE" "ci/jenkins/scripts/notify_n8n.sh"

assert_file_contains "$JENKINSFILE" "DOCKERHUB_REPO"

printf 'PASS: test_jenkinsfile_structure.sh\n'
