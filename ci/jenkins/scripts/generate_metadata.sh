#!/usr/bin/env bash

set -euo pipefail

: "${IMAGE_NAME:?IMAGE_NAME is required}"
: "${BUILD_DATE:?BUILD_DATE is required}"
: "${VERSION_DATE:?VERSION_DATE is required}"
: "${TAGS_FILE:?TAGS_FILE is required}"
: "${LABELS_FILE:?LABELS_FILE is required}"

IMAGE_DESC="${IMAGE_DESC:-My Customized Universal Blue Image With Cosmic DX Features}"
IMAGE_KEYWORDS="${IMAGE_KEYWORDS:-bootc,ublue,universal-blue,cosmic,cosmic-dx,custom-image}"
IMAGE_LOGO_URL="${IMAGE_LOGO_URL:-https://avatars.githubusercontent.com/u/120078124?s=200&v=4}"
IMAGE_LICENSE="${IMAGE_LICENSE:-Apache-2.0}"

GIT_SHA="${GIT_SHA:-$(git rev-parse HEAD 2>/dev/null || echo 'unknown')}"
REPO_URL="${REPO_URL:-$(git remote get-url origin 2>/dev/null | sed 's|^git@github.com:|https://github.com/|; s|\.git$||' || echo 'https://github.com/ericrocha97/bluefin')}"
REPO_PATH="${REPO_URL#https://github.com/}"
GITHUB_OWNER="${REPO_PATH%%/*}"

printf 'stable\nstable.%s\n%s\n' "$VERSION_DATE" "$VERSION_DATE" >"$TAGS_FILE"

printf '%s\n' \
    "org.opencontainers.image.created=$BUILD_DATE" \
    "org.opencontainers.image.title=$IMAGE_NAME" \
    "org.opencontainers.image.description=$IMAGE_DESC" \
    "org.opencontainers.image.documentation=https://raw.githubusercontent.com/${REPO_PATH}/${GIT_SHA}/README.md" \
    "org.opencontainers.image.source=https://github.com/${REPO_PATH}/blob/${GIT_SHA}/Containerfile" \
    "org.opencontainers.image.url=https://github.com/${REPO_PATH}/tree/${GIT_SHA}" \
    "org.opencontainers.image.vendor=$GITHUB_OWNER" \
    "org.opencontainers.image.version=stable.${VERSION_DATE}" \
    "io.artifacthub.package.readme-url=https://raw.githubusercontent.com/${REPO_PATH}/${GIT_SHA}/README.md" \
    "io.artifacthub.package.deprecated=false" \
    "io.artifacthub.package.keywords=$IMAGE_KEYWORDS" \
    "io.artifacthub.package.license=$IMAGE_LICENSE" \
    "io.artifacthub.package.logo-url=$IMAGE_LOGO_URL" \
    "io.artifacthub.package.prerelease=false" \
    "containers.bootc=1" >"$LABELS_FILE"
