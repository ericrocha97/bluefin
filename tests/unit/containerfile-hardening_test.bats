#!/usr/bin/env bats
# Static unit tests for the Containerfile build hardening (Task 3).
# These tests only read the Containerfile; they never start a build, so they
# are safe to run anywhere. Run with:
#   bats tests/unit/containerfile-hardening_test.bats
#
# shellcheck disable=SC2016  # ${...} patterns are literals matched with grep -F

CONTAINERFILE="${BATS_TEST_DIRNAME}/../../Containerfile"

# First line number (1-based) whose content contains the fixed string.
line_of() {
    grep -nF -- "$1" "${CONTAINERFILE}" | head -n1 | cut -d: -f1
}

# First line number whose content is exactly the fixed string.
line_of_exact() {
    grep -nF -x -- "$1" "${CONTAINERFILE}" | head -n1 | cut -d: -f1
}

# Print the full RUN instruction (joining backslash continuations) that
# contains the given fixed string.
run_block_containing() {
    awk -v needle="$1" '
        /^[[:space:]]*RUN[[:space:]]/ {
            block = $0
            while (block ~ /\\[[:space:]]*$/) {
                if ((getline next_line) <= 0) break
                block = block "\n" next_line
            }
            if (index(block, needle) > 0) {
                print block
                exit
            }
        }
    ' "${CONTAINERFILE}"
}

@test "declares the image identity ARGs after the base image, in order" {
    local from base image_name vendor tag base_name sha release
    from="$(line_of 'FROM ${BASE_IMAGE}')"
    base="$(line_of_exact 'ARG BASE_IMAGE')"
    image_name="$(line_of_exact 'ARG IMAGE_NAME="bluefin-cosmic-dx"')"
    vendor="$(line_of_exact 'ARG IMAGE_VENDOR="ericrocha97"')"
    tag="$(line_of_exact 'ARG UBLUE_IMAGE_TAG="stable"')"
    base_name="$(line_of_exact 'ARG BASE_IMAGE_NAME="bluefin-dx"')"
    sha="$(line_of_exact 'ARG SHA_HEAD_SHORT=""')"
    release="$(line_of_exact 'ARG RELEASE_TAG=""')"

    [ -n "${from}" ]
    [ -n "${base}" ]
    [ -n "${image_name}" ]
    [ -n "${vendor}" ]
    [ -n "${tag}" ]
    [ -n "${base_name}" ]
    [ -n "${sha}" ]
    [ -n "${release}" ]

    [ "${from}" -lt "${base}" ]
    [ "${base}" -lt "${image_name}" ]
    [ "${image_name}" -lt "${vendor}" ]
    [ "${vendor}" -lt "${tag}" ]
    [ "${tag}" -lt "${base_name}" ]
    [ "${base_name}" -lt "${sha}" ]
    [ "${sha}" -lt "${release}" ]
}

@test "generates image info before build, cleanup and strict lint" {
    local info build clean lint
    info="$(line_of '/ctx/build/00-image-info.sh')"
    build="$(line_of '/ctx/build/10-build.sh')"
    clean="$(line_of '/ctx/build/clean-stage.sh')"
    lint="$(line_of 'bootc container lint --fatal-warnings')"

    [ -n "${info}" ]
    [ -n "${build}" ]
    [ -n "${clean}" ]
    [ -n "${lint}" ]

    [ "${info}" -lt "${build}" ]
    [ "${build}" -lt "${clean}" ]
    [ "${clean}" -lt "${lint}" ]
}

@test "image-info RUN receives the identity variables" {
    local block
    block="$(run_block_containing '/ctx/build/00-image-info.sh')"
    [ -n "${block}" ]

    [[ "${block}" == *'BASE_IMAGE="${BASE_IMAGE}"'* ]]
    [[ "${block}" == *'IMAGE_NAME="${IMAGE_NAME}"'* ]]
    [[ "${block}" == *'IMAGE_VENDOR="${IMAGE_VENDOR}"'* ]]
    [[ "${block}" == *'UBLUE_IMAGE_TAG="${UBLUE_IMAGE_TAG}"'* ]]
    [[ "${block}" == *'BASE_IMAGE_NAME="${BASE_IMAGE_NAME}"'* ]]
}

@test "image-info RUN mounts tmpfs boot and tmp" {
    local block
    block="$(run_block_containing '/ctx/build/00-image-info.sh')"
    [ -n "${block}" ]

    [[ "${block}" == *'--mount=type=tmpfs,dst=/boot'* ]]
    [[ "${block}" == *'--mount=type=tmpfs,dst=/tmp'* ]]
}

@test "build RUN caches libdnf5 and rpm-ostree and mounts tmpfs boot and tmp" {
    local block
    block="$(run_block_containing '/ctx/build/10-build.sh')"
    [ -n "${block}" ]

    [[ "${block}" == *'--mount=type=cache,dst=/var/cache/libdnf5'* ]]
    [[ "${block}" == *'--mount=type=cache,dst=/var/cache/rpm-ostree'* ]]
    [[ "${block}" != *'--mount=type=cache,dst=/var/cache '* ]]
    [[ "${block}" != *'--mount=type=cache,dst=/var/log'* ]]
    [[ "${block}" == *'--mount=type=tmpfs,dst=/boot'* ]]
    [[ "${block}" == *'--mount=type=tmpfs,dst=/tmp'* ]]
}

@test "cleanup RUN mounts tmpfs boot and tmp" {
    local block
    block="$(run_block_containing '/ctx/build/clean-stage.sh')"
    [ -n "${block}" ]

    [[ "${block}" == *'--mount=type=tmpfs,dst=/boot'* ]]
    [[ "${block}" == *'--mount=type=tmpfs,dst=/tmp'* ]]
}
