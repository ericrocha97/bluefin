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
assert_file_contains "$JENKINSFILE" "stage('Push GHCR')"
assert_file_contains "$JENKINSFILE" "stage('Create GitHub Release')"
assert_file_contains "$JENKINSFILE" "stage('Resolve Branch Context')"

assert_file_contains "$JENKINSFILE" "post {"
assert_file_contains "$JENKINSFILE" "always {"
assert_file_contains "$JENKINSFILE" "currentBuild.currentResult"
assert_file_contains "$JENKINSFILE" "env.N8N_STATUS"
assert_file_contains "$JENKINSFILE" "notify_n8n.sh failed in post hook"

assert_file_contains "$JENKINSFILE" "ci/jenkins/scripts/generate_metadata.sh"
assert_file_contains "$JENKINSFILE" "ci/jenkins/scripts/extract_versions.sh"
assert_file_contains "$JENKINSFILE" "ci/jenkins/scripts/create_github_release.sh"
assert_file_contains "$JENKINSFILE" "ci/jenkins/scripts/notify_n8n.sh"

assert_file_contains "$JENKINSFILE" "IMAGE_REPOSITORY = 'ghcr.io/ericrocha97/bluefin-cosmic-dx'"
assert_file_contains "$JENKINSFILE" "credentialsId: 'ghcr-creds'"
assert_file_contains "$JENKINSFILE" "credentialsId: 'github-token', variable: 'GH_TOKEN'"
assert_file_contains "$JENKINSFILE" "credentialsId: 'n8n-webhook-url', variable: 'WEBHOOK_URL'"
assert_file_contains "$JENKINSFILE" "credentialsId: 'n8n-webhook-token', variable: 'N8N_WEBHOOK_SHARED_TOKEN'"
assert_file_contains "$JENKINSFILE" "docker login \"\$IMAGE_REGISTRY\" -u \"\$GHCR_USERNAME\" --password-stdin"
assert_file_contains "$JENKINSFILE" "docker build --pull -f Containerfile"
assert_file_contains "$JENKINSFILE" "--build-arg RELEASE_TAG=\"v\${short_date}\""
assert_file_contains "$JENKINSFILE" "\"\${labels_args[@]}\""
assert_file_contains "$JENKINSFILE" "-t \"\$IMAGE_REPOSITORY:\${short_date}\" ."
assert_file_contains "$JENKINSFILE" "short_date=\"\${SHORT_DATE:-}\""
assert_file_contains "$JENKINSFILE" "if [[ -z \"\$short_date\" && -f ci/jenkins/build/short_date ]]; then"
assert_file_contains "$JENKINSFILE" "release_tag=\"\${RELEASE_TAG:-}\""
assert_file_contains "$JENKINSFILE" "if [[ -z \"\$release_tag\" && -f ci/jenkins/build/release_tag ]]; then"
assert_file_contains "$JENKINSFILE" "trap cleanup EXIT"
assert_file_contains "$JENKINSFILE" "def branch = (env.BRANCH_NAME ?: env.GIT_BRANCH ?: '')"
assert_file_contains "$JENKINSFILE" "branch = branch.replaceFirst('^origin/', '').replaceFirst('^refs/heads/', '')"
assert_file_contains "$JENKINSFILE" "if (!branch) {"
assert_file_contains "$JENKINSFILE" "git rev-parse --abbrev-ref HEAD"
assert_file_contains "$JENKINSFILE" "if (gitBranch != 'HEAD') {"
assert_file_contains "$JENKINSFILE" "branch = 'unknown'"
assert_file_contains "$JENKINSFILE" "release stages will be skipped"
assert_file_contains "$JENKINSFILE" "expression { env.EFFECTIVE_BRANCH == env.DEFAULT_BRANCH }"

assert_file_contains "$JENKINSFILE" "rpm -qa --queryformat '%{NAME}\\t%{VERSION}-%{RELEASE}\\n'"
assert_file_contains "$JENKINSFILE" "awk -F= '\$1==\"IMAGE_VERSION\" {gsub(/\"/,\"\",\$2); print \$2; exit}' /etc/os-release > ci/jenkins/build/bluefin_version"
assert_file_contains "$JENKINSFILE" "if [[ ! -s ci/jenkins/build/bluefin_version ]]; then"
assert_file_contains "$JENKINSFILE" "awk -F= '\$1==\"VERSION_ID\" {gsub(/\"/,\"\",\$2); print \$2; exit}' /etc/os-release > ci/jenkins/build/bluefin_version"
assert_file_contains "$JENKINSFILE" "if [[ ! -s ci/jenkins/build/bluefin_version ]]; then"
assert_file_contains "$JENKINSFILE" "printf 'unknown\\n' > ci/jenkins/build/bluefin_version"
assert_file_contains "$JENKINSFILE" "gh release list --limit 100 --json tagName --jq '.[] | .tagName'"
assert_file_contains "$JENKINSFILE" "awk -v current=\"\$RELEASE_TAG\" '\$0 != current { print; exit }'"
assert_file_contains "$JENKINSFILE" "gh release download \"\$previous_release_tag\" --pattern \"\$(basename \"\$MANIFEST_FILE\")\""

assert_file_contains "$JENKINSFILE" "if gh release view \"\$release_tag\" >/dev/null 2>&1; then"
assert_file_contains "$JENKINSFILE" "gh release edit \"\$release_tag\" --title \"\$release_tag\" --notes-file \"\$RELEASE_BODY_FILE\""
assert_file_contains "$JENKINSFILE" "gh release create \"\$release_tag\" --title \"\$release_tag\" --notes-file \"\$RELEASE_BODY_FILE\""
assert_file_contains "$JENKINSFILE" "gh release upload \"\$release_tag\" \"\$MANIFEST_FILE\" --clobber"
assert_file_contains "$JENKINSFILE" "git_sha=\"\${GIT_COMMIT:-\${GIT_PREVIOUS_SUCCESSFUL_COMMIT:-unknown}}\""
assert_file_contains "$JENKINSFILE" "if [[ -z \"\$build_started_at\" && -f ci/jenkins/build/started_at ]]; then"

printf 'PASS: test_jenkinsfile_structure.sh\n'
