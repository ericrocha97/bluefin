#!/usr/bin/env bash
set -euo pipefail

BASE_IMAGE="${BASE_IMAGE:-}"
IMAGE_NAME="${IMAGE_NAME:-bluefin-cosmic-dx}"
IMAGE_VENDOR="${IMAGE_VENDOR:-ericrocha97}"
UBLUE_IMAGE_TAG="${UBLUE_IMAGE_TAG:-stable}"
BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-bluefin-dx}"
IMAGE_INFO="${IMAGE_INFO:-/usr/share/ublue-os/image-info.json}"
OS_RELEASE="${OS_RELEASE:-/usr/lib/os-release}"

image_name="${IMAGE_NAME}"
image_flavor="main"
if [[ "${BASE_IMAGE}" == *nvidia* ]]; then
    image_name="${image_name}-nvidia"
    image_flavor="nvidia"
fi

fedora_version="$(awk -F= '$1 == "VERSION_ID" { gsub(/"/, "", $2); print $2; exit }' "${OS_RELEASE}")"
: "${fedora_version:?VERSION_ID is required}"

install -d -m 0755 "$(dirname "${IMAGE_INFO}")"
cat > "${IMAGE_INFO}" <<EOF
{
  "image-name": "${image_name}",
  "image-flavor": "${image_flavor}",
  "image-vendor": "${IMAGE_VENDOR}",
  "image-ref": "ostree-unverified-registry:docker://ghcr.io/${IMAGE_VENDOR}/${image_name}",
  "image-tag": "${UBLUE_IMAGE_TAG}",
  "base-image-name": "${BASE_IMAGE_NAME}",
  "fedora-version": "${fedora_version}"
}
EOF
