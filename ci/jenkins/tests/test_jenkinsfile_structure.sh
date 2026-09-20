#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/assert.sh"

# Assert that the first occurrence of $first appears before the first occurrence
# of $second in $file. Used to pin stage ordering in the pipelines.
assert_ordered_in_file() {
    local file_path="$1"
    local first="$2"
    local second="$3"
    local first_line second_line

    first_line="$(grep -nF -- "$first" "$file_path" | head -n1 | cut -d: -f1)"
    second_line="$(grep -nF -- "$second" "$file_path" | head -n1 | cut -d: -f1)"

    if [[ -z "$first_line" || -z "$second_line" ]]; then
        fail "Cannot verify ordering '$first' before '$second' in $file_path"
    fi

    if (( first_line >= second_line )); then
        fail "Expected '$first' (line $first_line) before '$second' (line $second_line) in $file_path"
    fi
}

# Assert that the body of a single `stage('NAME') { ... }` block contains a
# literal string. The body is bounded by the next top-level `stage(` line.
assert_stage_block_contains() {
    local file_path="$1"
    local stage_name="$2"
    local expected_text="$3"
    local target="stage('$stage_name')"
    local block

    block="$(awk -v target="$target" '
        index($0, target) > 0 { capture = 1 }
        capture { print }
        capture && index($0, target) == 0 && $0 ~ /^        stage\(/ { exit }
    ' "$file_path")"

    if [[ "$block" != *"$expected_text"* ]]; then
        fail "Expected '$expected_text' inside $target in $file_path"
    fi
}

assert_stage_block_not_contains() {
    local file_path="$1"
    local stage_name="$2"
    local unexpected_text="$3"
    local target="stage('$stage_name')"
    local block

    block="$(awk -v target="$target" '
        index($0, target) > 0 { capture = 1 }
        capture { print }
        capture && index($0, target) == 0 && $0 ~ /^        stage\(/ { exit }
    ' "$file_path")"

    if [[ "$block" == *"$unexpected_text"* ]]; then
        fail "Did not expect '$unexpected_text' inside $target in $file_path"
    fi
}

JENKINSFILE_STABLE="$REPO_ROOT/ci/jenkins/Jenkinsfile.stable"
JENKINSFILE_NVIDIA="$REPO_ROOT/ci/jenkins/Jenkinsfile.nvidia"

for JENKINSFILE in "$JENKINSFILE_STABLE" "$JENKINSFILE_NVIDIA"; do
    assert_file_contains "$JENKINSFILE" "pipeline {"
    assert_file_contains "$JENKINSFILE" "disableConcurrentBuilds(abortPrevious: true)"

    assert_file_contains "$JENKINSFILE" "stage('Build Image')"
    assert_file_contains "$JENKINSFILE" "stage('Push GHCR')"
    assert_file_contains "$JENKINSFILE" "stage('Create GitHub Release')"
    assert_file_contains "$JENKINSFILE" "stage('Promote Stable')"
    assert_file_contains "$JENKINSFILE" "stage('Resolve Branch Context')"

    assert_file_contains "$JENKINSFILE" "post {"
    assert_file_contains "$JENKINSFILE" "always {"
    assert_file_contains "$JENKINSFILE" "currentBuild.currentResult"
    assert_file_contains "$JENKINSFILE" "env.N8N_STATUS"
    assert_file_contains "$JENKINSFILE" "notify_n8n.sh failed in post hook"

    assert_file_contains "$JENKINSFILE" "DEFAULT_BRANCH = 'main'"

    assert_file_contains "$JENKINSFILE" "ci/jenkins/scripts/generate_metadata.sh"
    assert_file_contains "$JENKINSFILE" "ci/jenkins/scripts/extract_versions.sh"
    assert_file_contains "$JENKINSFILE" "ci/jenkins/scripts/create_github_release.sh"
    assert_file_contains "$JENKINSFILE" "ci/jenkins/scripts/notify_n8n.sh"

    assert_file_contains "$JENKINSFILE" "credentialsId: 'ghcr-creds'"
    assert_file_contains "$JENKINSFILE" "credentialsId: 'github-token', variable: 'GH_TOKEN'"
    assert_file_contains "$JENKINSFILE" "credentialsId: 'n8n-webhook-url', variable: 'WEBHOOK_URL'"
    assert_file_contains "$JENKINSFILE" "credentialsId: 'n8n-webhook-token', variable: 'N8N_WEBHOOK_SHARED_TOKEN'"

    assert_file_contains "$JENKINSFILE" "docker login \"\$IMAGE_REGISTRY\" -u \"\$GHCR_USERNAME\" --password-stdin"
    assert_file_contains "$JENKINSFILE" "docker build --pull -f Containerfile"
    assert_file_contains "$JENKINSFILE" "ci/jenkins/scripts/generate_metadata.sh"
    assert_file_contains "$JENKINSFILE" "\"\${labels_args[@]}\""
    assert_file_contains "$JENKINSFILE" "-t \"\$IMAGE_REPOSITORY:\${short_date}\" ."
    assert_file_contains "$JENKINSFILE" "short_date=\"\${SHORT_DATE:-}\""
    assert_file_contains "$JENKINSFILE" "if [[ -z \"\$short_date\" && -f ci/jenkins/build/short_date ]]; then"
    assert_file_contains "$JENKINSFILE" "release_tag=\"\${RELEASE_TAG:-}\""
    assert_file_contains "$JENKINSFILE" "if [[ -z \"\$release_tag\" && -f ci/jenkins/build/release_tag ]]; then"
    assert_file_contains "$JENKINSFILE" "trap cleanup EXIT"
    assert_file_contains "$JENKINSFILE" "[[ \"\$tag\" == \"stable\" ]] && continue"
    assert_file_contains "$JENKINSFILE" "awk '{print \$2}' || true)"
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
done

# Standard variant (bluefin-cosmic-dx)
assert_file_contains "$JENKINSFILE_STABLE" "cron('H 2 * * 0')"
assert_file_contains "$JENKINSFILE_STABLE" "IMAGE_NAME = 'bluefin-cosmic-dx'"
assert_file_contains "$JENKINSFILE_STABLE" "IMAGE_REPOSITORY = 'ghcr.io/ericrocha97/bluefin-cosmic-dx'"
assert_stage_block_contains "$JENKINSFILE_STABLE" "Push GHCR" "artifacthub-repo.yml:application/vnd.cncf.artifacthub.repository-metadata.layer.v1.yaml"
assert_file_contains "$JENKINSFILE_STABLE" "echo \"v\${short_date}\" > ci/jenkins/build/release_tag"
assert_file_contains "$JENKINSFILE_STABLE" "--build-arg RELEASE_TAG=\"v\${short_date}\""
assert_file_not_contains "$JENKINSFILE_STABLE" "--build-arg BASE_IMAGE"

# Standard variant: Cosign signing by digest, after Push GHCR and before the
# release. It only runs on the default branch and binds the two credentials.
assert_file_contains "$JENKINSFILE_STABLE" "stage('Sign Image')"
    assert_ordered_in_file "$JENKINSFILE_STABLE" "stage('Push GHCR')" "stage('Sign Image')"
    assert_ordered_in_file "$JENKINSFILE_STABLE" "stage('Sign Image')" "stage('Create GitHub Release')"
    assert_ordered_in_file "$JENKINSFILE_STABLE" "stage('Sign Image')" "stage('Promote Stable')"
    assert_ordered_in_file "$JENKINSFILE_STABLE" "stage('Promote Stable')" "stage('Create GitHub Release')"
assert_stage_block_contains "$JENKINSFILE_STABLE" "Sign Image" "expression { env.EFFECTIVE_BRANCH == env.DEFAULT_BRANCH }"
assert_stage_block_contains "$JENKINSFILE_STABLE" "Sign Image" "credentialsId: 'cosign_key', variable: 'COSIGN_KEY_FILE'"
    assert_stage_block_contains "$JENKINSFILE_STABLE" "Sign Image" "credentialsId: 'cosign_pass', variable: 'COSIGN_PASSWORD'"
    assert_stage_block_contains "$JENKINSFILE_STABLE" "Sign Image" "credentialsId: 'ghcr-creds'"
    assert_stage_block_contains "$JENKINSFILE_STABLE" "Sign Image" "docker login \"\$IMAGE_REGISTRY\" -u \"\$GHCR_USERNAME\" --password-stdin"
    assert_stage_block_contains "$JENKINSFILE_STABLE" "Sign Image" "bash ci/jenkins/scripts/sign_image.sh \"\${IMAGE_REPOSITORY}@\${digest}\""
    assert_stage_block_contains "$JENKINSFILE_STABLE" "Promote Stable" "docker push \"\$IMAGE_REPOSITORY:stable\""

# The published digest is captured from the push output, validated, written for
# the signing stage and never replaced by a bare tag.
assert_stage_block_contains "$JENKINSFILE_STABLE" "Push GHCR" 'sha256:[0-9a-f]{64}'
assert_stage_block_not_contains "$JENKINSFILE_STABLE" "Push GHCR" "docker push \"\$IMAGE_REPOSITORY:stable\""
assert_file_contains "$JENKINSFILE_STABLE" "ci/jenkins/build/image_digest"
assert_file_contains "$JENKINSFILE_STABLE" "if [[ ! \"\$digest\" =~ ^sha256:[0-9a-f]{64}\$ ]]; then"
assert_file_not_contains "$JENKINSFILE_STABLE" "cosign sign \"\$IMAGE_REPOSITORY:"

# Run the real `captured_digest=...` command from the Push GHCR stage against a
# sample docker push log and return the digest it extracts. The command is read
# from the given Jenkinsfile so the test exercises the pipeline logic instead of
# a copy of it.
run_push_digest_extraction() {
    local jenkinsfile_path="$1"
    local push_log_content="$2"
    local command inner result tmp
    tmp="$(mktemp -d)"

    command="$(grep -F "captured_digest=\"\$(" "$jenkinsfile_path" | head -n1)"
    if [[ -z "$command" ]]; then
        rm -rf "$tmp"
        fail "Cannot locate the digest extraction command in $jenkinsfile_path"
    fi

    mkdir -p "$tmp/ci/jenkins/build"
    printf '%s\n' "$push_log_content" > "$tmp/ci/jenkins/build/push.log"

    command="${command%"${command##*[![:space:]]}"}"
    inner="${command#*captured_digest=\"\$(}"
    inner="${inner%)\"}"

    result="$(cd "$tmp" && eval "$inner")"
    rm -rf "$tmp"
    printf '%s' "$result"
}

# A push log can carry earlier sha256 tokens (layer/config digests) before the
# final `digest:` line; the final manifest digest must win.
push_log_sample='The push refers to repository [ghcr.io/ericrocha97/bluefin-cosmic-dx]
layer-sha is sha256:1111111111111111111111111111111111111111111111111111111111111111
config: digest: sha256:2222222222222222222222222222222222222222222222222222222222222222 size: 100
latest: digest: sha256:3333333333333333333333333333333333333333333333333333333333333333 size: 1234'

final_digest="sha256:3333333333333333333333333333333333333333333333333333333333333333"
earlier_digest="sha256:1111111111111111111111111111111111111111111111111111111111111111"
captured_digest="$(run_push_digest_extraction "$JENKINSFILE_STABLE" "$push_log_sample")"
assert_equals "$final_digest" "$captured_digest" "Push GHCR must capture the final published digest"
if [[ "$captured_digest" == "$earlier_digest" ]]; then
    fail "Push GHCR captured an earlier sha256 token instead of the final digest"
fi

# Regression guard: the extraction must anchor on the final `digest:` line and
# must not fall back to "first sha256 token anywhere".
assert_stage_block_contains "$JENKINSFILE_STABLE" "Push GHCR" "digest: sha256:"
assert_file_not_contains "$JENKINSFILE_STABLE" 'for (i = 1; i <= NF; i++)'

# NVIDIA variant (bluefin-cosmic-dx-nvidia)
assert_file_contains "$JENKINSFILE_NVIDIA" "cron('H 10 * * *')"
assert_file_contains "$JENKINSFILE_NVIDIA" "IMAGE_NAME = 'bluefin-cosmic-dx-nvidia'"
assert_file_contains "$JENKINSFILE_NVIDIA" "IMAGE_REPOSITORY = 'ghcr.io/ericrocha97/bluefin-cosmic-dx-nvidia'"
assert_file_contains "$JENKINSFILE_NVIDIA" "echo \"v\${short_date}-nvidia\" > ci/jenkins/build/release_tag"
assert_file_contains "$JENKINSFILE_NVIDIA" "--build-arg BASE_IMAGE=ghcr.io/ublue-os/bluefin-dx-nvidia-open:stable-daily"
assert_file_contains "$JENKINSFILE_NVIDIA" "--build-arg RELEASE_TAG=\"v\${short_date}-nvidia\""

# NVIDIA variant: Cosign signing by digest, after Push GHCR and before the
# release. It only runs on the default branch and binds the two credentials,
# mirroring the standard pipeline without touching the NVIDIA base image or the
# existing release tag.
    assert_file_contains "$JENKINSFILE_NVIDIA" "stage('Sign Image')"
    assert_file_contains "$JENKINSFILE_NVIDIA" "stage('Promote Stable')"
    assert_ordered_in_file "$JENKINSFILE_NVIDIA" "stage('Push GHCR')" "stage('Sign Image')"
    assert_ordered_in_file "$JENKINSFILE_NVIDIA" "stage('Sign Image')" "stage('Create GitHub Release')"
    assert_ordered_in_file "$JENKINSFILE_NVIDIA" "stage('Sign Image')" "stage('Promote Stable')"
    assert_ordered_in_file "$JENKINSFILE_NVIDIA" "stage('Promote Stable')" "stage('Create GitHub Release')"
assert_stage_block_contains "$JENKINSFILE_NVIDIA" "Sign Image" "expression { env.EFFECTIVE_BRANCH == env.DEFAULT_BRANCH }"
assert_stage_block_contains "$JENKINSFILE_NVIDIA" "Sign Image" "credentialsId: 'cosign_key', variable: 'COSIGN_KEY_FILE'"
    assert_stage_block_contains "$JENKINSFILE_NVIDIA" "Sign Image" "credentialsId: 'cosign_pass', variable: 'COSIGN_PASSWORD'"
    assert_stage_block_contains "$JENKINSFILE_NVIDIA" "Sign Image" "credentialsId: 'ghcr-creds'"
    assert_stage_block_contains "$JENKINSFILE_NVIDIA" "Sign Image" "docker login \"\$IMAGE_REGISTRY\" -u \"\$GHCR_USERNAME\" --password-stdin"
    assert_stage_block_contains "$JENKINSFILE_NVIDIA" "Sign Image" "bash ci/jenkins/scripts/sign_image.sh \"\${IMAGE_REPOSITORY}@\${digest}\""
    assert_stage_block_contains "$JENKINSFILE_NVIDIA" "Promote Stable" "docker push \"\$IMAGE_REPOSITORY:stable\""

# The published digest is captured from the push output, validated, written for
# the signing stage and never replaced by a bare tag.
assert_stage_block_contains "$JENKINSFILE_NVIDIA" "Push GHCR" 'sha256:[0-9a-f]{64}'
assert_stage_block_not_contains "$JENKINSFILE_NVIDIA" "Push GHCR" "docker push \"\$IMAGE_REPOSITORY:stable\""
assert_file_contains "$JENKINSFILE_NVIDIA" "ci/jenkins/build/image_digest"
assert_file_contains "$JENKINSFILE_NVIDIA" "if [[ ! \"\$digest\" =~ ^sha256:[0-9a-f]{64}\$ ]]; then"
assert_file_not_contains "$JENKINSFILE_NVIDIA" "cosign sign \"\$IMAGE_REPOSITORY:"
assert_stage_block_contains "$JENKINSFILE_NVIDIA" "Push GHCR" "digest: sha256:"
assert_file_not_contains "$JENKINSFILE_NVIDIA" 'for (i = 1; i <= NF; i++)'

# The same extraction logic must run against the NVIDIA pipeline. The final
# manifest digest must win over earlier layer/config sha256 tokens.
nvidia_push_log_sample='The push refers to repository [ghcr.io/ericrocha97/bluefin-cosmic-dx-nvidia]
layer-sha is sha256:4444444444444444444444444444444444444444444444444444444444444444
config: digest: sha256:5555555555555555555555555555555555555555555555555555555555555555 size: 100
stable: digest: sha256:6666666666666666666666666666666666666666666666666666666666666666 size: 4321'

nvidia_final_digest="sha256:6666666666666666666666666666666666666666666666666666666666666666"
nvidia_earlier_digest="sha256:4444444444444444444444444444444444444444444444444444444444444444"
nvidia_captured_digest="$(run_push_digest_extraction "$JENKINSFILE_NVIDIA" "$nvidia_push_log_sample")"
assert_equals "$nvidia_final_digest" "$nvidia_captured_digest" "NVIDIA Push GHCR must capture the final published digest"
if [[ "$nvidia_captured_digest" == "$nvidia_earlier_digest" ]]; then
    fail "NVIDIA Push GHCR captured an earlier sha256 token instead of the final digest"
fi

printf 'PASS: test_jenkinsfile_structure.sh\n'
