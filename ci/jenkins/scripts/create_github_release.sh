#!/usr/bin/env bash

set -euo pipefail

render_only="false"
if [[ "${1:-}" == "--render-only" ]]; then
    render_only="true"
fi

: "${RELEASE_TAG:?RELEASE_TAG is required}"
: "${IMAGE_REGISTRY:?IMAGE_REGISTRY is required}"
: "${IMAGE_NAME:?IMAGE_NAME is required}"
: "${SHORT_DATE:?SHORT_DATE is required}"
: "${BLUEFIN_VERSION:?BLUEFIN_VERSION is required}"
: "${KERNEL_VERSION:?KERNEL_VERSION is required}"
: "${VSCODE_VERSION:?VSCODE_VERSION is required}"
: "${WARP_VERSION:?WARP_VERSION is required}"
: "${VICINAE_VERSION:?VICINAE_VERSION is required}"
: "${COSMIC_SESSION_VERSION:?COSMIC_SESSION_VERSION is required}"
: "${CHANGELOG:?CHANGELOG is required}"
: "${IMAGE_PACKAGE_URL:?IMAGE_PACKAGE_URL is required}"
: "${RELEASE_BODY_FILE:?RELEASE_BODY_FILE is required}"
: "${MANIFEST_FILE:?MANIFEST_FILE is required}"

cat >"$RELEASE_BODY_FILE" <<EOF
## Container Image ✨


\`${IMAGE_REGISTRY}/${IMAGE_NAME}:${SHORT_DATE}\`

## Package Versions 📦

| Component | Version |
| --- | --- |
| Bluefin | ${BLUEFIN_VERSION} |
| Kernel | ${KERNEL_VERSION} |
| VSCode Insiders | ${VSCODE_VERSION} |
| Warp Terminal | ${WARP_VERSION} |
| Vicinae | ${VICINAE_VERSION} |
| COSMIC Session | ${COSMIC_SESSION_VERSION} |

## Changes Since Previous Release 📝

${CHANGELOG}

[View on GitHub Container Registry](${IMAGE_PACKAGE_URL})
EOF

if [[ "$render_only" == "true" ]]; then
    exit 0
fi

gh release create "$RELEASE_TAG" "$MANIFEST_FILE" \
    --title "$RELEASE_TAG" \
    --notes-file "$RELEASE_BODY_FILE"
