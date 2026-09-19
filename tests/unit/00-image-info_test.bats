#!/usr/bin/env bats

setup() {
    export IMAGE_INFO="${BATS_TEST_TMPDIR}/usr/share/ublue-os/image-info.json"
    export OS_RELEASE="${BATS_TEST_TMPDIR}/os-release"
    printf 'NAME="Fedora Linux"\nVERSION_ID="44"\n' > "${OS_RELEASE}"
    cp "${OS_RELEASE}" "${OS_RELEASE}.before"
}

run_image_info() {
    run env \
        BASE_IMAGE="$1" \
        IMAGE_INFO="${IMAGE_INFO}" \
        OS_RELEASE="${OS_RELEASE}" \
        bash "${BATS_TEST_DIRNAME}/../../build/00-image-info.sh"
}

assert_image_info() {
    python3 - "$1" "$2" "${IMAGE_INFO}" <<'PY'
import json
import sys

expected_name, expected_flavor, image_info = sys.argv[1:]
with open(image_info, encoding="utf-8") as stream:
    actual = json.load(stream)

expected = {
    "image-name": expected_name,
    "image-flavor": expected_flavor,
    "image-vendor": "ericrocha97",
    "image-ref": (
        "ostree-unverified-registry:docker://ghcr.io/"
        f"ericrocha97/{expected_name}"
    ),
    "image-tag": "stable",
    "base-image-name": "bluefin-dx",
    "fedora-version": "44",
}

assert actual == expected, f"expected {expected!r}, got {actual!r}"
PY
}

@test "writes valid metadata for the standard image without changing os-release" {
    run_image_info "ghcr.io/ublue-os/bluefin-dx:stable"

    [ "${status}" -eq 0 ]
    assert_image_info "bluefin-cosmic-dx" "main"
    cmp "${OS_RELEASE}.before" "${OS_RELEASE}"
}

@test "writes valid metadata for the NVIDIA image without changing os-release" {
    run_image_info "ghcr.io/ublue-os/bluefin-dx-nvidia-open:stable"

    [ "${status}" -eq 0 ]
    assert_image_info "bluefin-cosmic-dx-nvidia" "nvidia"
    cmp "${OS_RELEASE}.before" "${OS_RELEASE}"
}
