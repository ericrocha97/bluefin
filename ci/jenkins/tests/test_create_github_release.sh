#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/assert.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

SCRIPT_PATH="$REPO_ROOT/ci/jenkins/scripts/create_github_release.sh"
RELEASE_BODY_FILE="$TMPDIR/release-body.md"
MANIFEST_FILE="$TMPDIR/manifest.txt"
GH_CALLS_FILE="$TMPDIR/gh-calls.txt"

mkdir -p "$TMPDIR/bin"
cat >"$TMPDIR/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$GH_CALLS_FILE"
EOF
chmod +x "$TMPDIR/bin/gh"

printf 'kernel\t6.8.12\n' >"$MANIFEST_FILE"

export PATH="$TMPDIR/bin:$PATH"
export GH_CALLS_FILE
export RELEASE_TAG="v20260403"
export IMAGE_REGISTRY="ghcr.io"
export IMAGE_NAME="example/bluefin-cosmic-dx"
export SHORT_DATE="20260403"
export BLUEFIN_VERSION="42.20260401"
export KERNEL_VERSION="6.8.12-300.fc42.x86_64"
export VSCODE_VERSION="1.92.0-1722860000.el8"
export WARP_VERSION="0.2024.08.14.08.02.stable_00-1"
export VICINAE_VERSION="0.5.2-1"
export COSMIC_SESSION_VERSION="1.0.0~alpha.7-1"
export CHANGELOG=$'- code-insiders: 1.91.0 -> 1.92.0\n- warp-terminal: 0.2024.08.01 -> 0.2024.08.14'
export DOCKERHUB_REPO="ericrocha97/bluefin-cosmic-dx"
export RELEASE_BODY_FILE
export MANIFEST_FILE

bash "$SCRIPT_PATH" --render-only

assert_file_contains "$RELEASE_BODY_FILE" "## Container Image"
assert_file_contains "$RELEASE_BODY_FILE" "\`ghcr.io/example/bluefin-cosmic-dx:20260403\`"
assert_file_contains "$RELEASE_BODY_FILE" "## Package Versions"
assert_file_contains "$RELEASE_BODY_FILE" "| Bluefin | 42.20260401 |"
assert_file_contains "$RELEASE_BODY_FILE" "| Kernel | 6.8.12-300.fc42.x86_64 |"
assert_file_contains "$RELEASE_BODY_FILE" "| VSCode Insiders | 1.92.0-1722860000.el8 |"
assert_file_contains "$RELEASE_BODY_FILE" "| Warp Terminal | 0.2024.08.14.08.02.stable_00-1 |"
assert_file_contains "$RELEASE_BODY_FILE" "| Vicinae | 0.5.2-1 |"
assert_file_contains "$RELEASE_BODY_FILE" "| COSMIC Session | 1.0.0~alpha.7-1 |"
assert_file_contains "$RELEASE_BODY_FILE" "## Changes Since Previous Release"
assert_file_contains "$RELEASE_BODY_FILE" "code-insiders: 1.91.0 -> 1.92.0"
assert_file_contains "$RELEASE_BODY_FILE" "warp-terminal: 0.2024.08.01 -> 0.2024.08.14"
assert_file_contains "$RELEASE_BODY_FILE" "[View on Docker Hub](https://hub.docker.com/r/ericrocha97/bluefin-cosmic-dx)"

if [[ -f "$GH_CALLS_FILE" ]]; then
    fail "Render-only mode should not invoke gh"
fi

bash "$SCRIPT_PATH"

assert_file_contains "$GH_CALLS_FILE" "release create v20260403"
assert_file_contains "$GH_CALLS_FILE" "title v20260403"
assert_file_contains "$GH_CALLS_FILE" "notes-file $RELEASE_BODY_FILE"
assert_file_contains "$GH_CALLS_FILE" "$MANIFEST_FILE"

printf 'PASS: test_create_github_release.sh\n'
