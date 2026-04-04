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
assert_file_contains "$JENKINSFILE" "credentialsId: 'dockerhub-creds'"
assert_file_contains "$JENKINSFILE" "docker login -u \"\$DOCKERHUB_USERNAME\" --password-stdin"

assert_file_contains "$JENKINSFILE" "rpm -qa --queryformat '%{NAME}\\t%{VERSION}-%{RELEASE}\\n'"
assert_file_contains "$JENKINSFILE" "gh release view --json tagName --jq '.tagName'"
assert_file_contains "$JENKINSFILE" "gh release download \"\$latest_release_tag\" --pattern \"\$(basename \"\$MANIFEST_FILE\")\""

assert_file_contains "$JENKINSFILE" "if gh release view \"\$RELEASE_TAG\" >/dev/null 2>&1; then"
assert_file_contains "$JENKINSFILE" "gh release edit \"\$RELEASE_TAG\" --title \"\$RELEASE_TAG\" --notes-file \"\$RELEASE_BODY_FILE\""
assert_file_contains "$JENKINSFILE" "gh release create \"\$RELEASE_TAG\" --title \"\$RELEASE_TAG\" --notes-file \"\$RELEASE_BODY_FILE\""
assert_file_contains "$JENKINSFILE" "gh release upload \"\$RELEASE_TAG\" \"\$MANIFEST_FILE\" --clobber"

printf 'PASS: test_jenkinsfile_structure.sh\n'
