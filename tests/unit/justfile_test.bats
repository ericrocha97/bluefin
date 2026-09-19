#!/usr/bin/env bats
# Static contract tests for the root Justfile.
#
# These tests only read the Justfile; they never run `just` and never start a
# build. CI installs bats/jq but not `just`, so the contracts are asserted
# textually instead of through `just --dry-run`.
#
# Run with: bats tests/unit/justfile_test.bats

JUSTFILE="${BATS_TEST_DIRNAME}/../../Justfile"

# Print the body of a recipe whose header ends in `:` (arguments allowed).
recipe_body() {
    local recipe="$1"
    awk -v recipe="${recipe}" '
        $0 ~ ("^" recipe "([ ][^:]*)?:$") { in_recipe = 1; next }
        in_recipe && /^[^[:space:]]/ { exit }
        in_recipe { print }
    ' "${JUSTFILE}"
}

@test "Justfile: build gates the SHA build arg on a clean tree" {
    run recipe_body build

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"podman build"* ]]
    [[ "${output}" == *"--pull=newer"* ]]
    [[ "${output}" == *'--tag "${target_image}:${tag}"'* ]]
    # The short SHA must be tied to the clean-tree guard, not merely present
    # somewhere in the recipe.
    [[ "${output}" == *'if [[ -z "$(git status -s)" ]]; then'* ]]
    [[ "${output}" == *'BUILD_ARGS+=("--build-arg" "SHA_HEAD_SHORT=$(git rev-parse --short HEAD)")'* ]]
}

@test "Justfile: build-nvidia overrides BASE_IMAGE with the NVIDIA variant" {
    run recipe_body build-nvidia

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"--build-arg BASE_IMAGE=ghcr.io/ublue-os/bluefin-dx-nvidia-open:stable-daily"* ]]

    run recipe_body build
    [[ "${output}" != *"--build-arg BASE_IMAGE="* ]]
}

@test "Justfile: lint recipe runs shellcheck over *.sh" {
    run recipe_body lint

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"shellcheck"* ]]
    [[ "${output}" == *'*.sh'* ]]
}

@test "Justfile: check recipe validates just formatting for Justfile and *.just" {
    run recipe_body check

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"--unstable --fmt --check"* ]]
    # Pin the scope to *.just files plus the root Justfile: `check` must not
    # drift onto the shell scripts owned by `lint`.
    [[ "${output}" == *'find . -type f -name "*.just"'* ]]
    [[ "${output}" == *'just --unstable --fmt --check -f Justfile'* ]]
}

@test "Justfile: validate recipes delegate to the build validators" {
    run recipe_body validate-brewfiles
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"bash build/validate-brewfiles.sh custom/brew"* ]]

    run recipe_body validate-flatpaks
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"bash build/validate-flatpaks.sh custom/flatpaks"* ]]
}

@test "Justfile: image identity defaults match the repository" {
    run grep -F 'export image_name := env("IMAGE_NAME", "bluefin-cosmic-dx")' "${JUSTFILE}"
    [ "${status}" -eq 0 ]

    run grep -F 'export image_name_nvidia := env("IMAGE_NAME_NVIDIA", "bluefin-cosmic-dx-nvidia")' "${JUSTFILE}"
    [ "${status}" -eq 0 ]

    run grep -F 'export default_tag := env("DEFAULT_TAG", "stable")' "${JUSTFILE}"
    [ "${status}" -eq 0 ]
}

@test "Justfile: VM aliases point at the qcow2 recipes" {
    run grep -F 'alias build-vm := build-qcow2' "${JUSTFILE}"
    [ "${status}" -eq 0 ]

    run grep -F 'alias run-vm := run-vm-qcow2' "${JUSTFILE}"
    [ "${status}" -eq 0 ]
}

@test "Justfile: BIB recipes use the expected config files" {
    run grep -F '"iso/disk.toml"' "${JUSTFILE}"
    [ "${status}" -eq 0 ]

    run grep -F '"iso/iso.toml"' "${JUSTFILE}"
    [ "${status}" -eq 0 ]

    run grep -F '"iso/iso-nvidia.toml"' "${JUSTFILE}"
    [ "${status}" -eq 0 ]
}

@test "Justfile: no recipe calls dnf5 or rpm-ostree directly" {
    run grep -nE '(^|[^A-Za-z0-9_-])(dnf5|rpm-ostree)([^A-Za-z0-9_-]|$)' "${JUSTFILE}"
    [ "${status}" -ne 0 ]
}

@test "Justfile: test-unit runs the BATS suite with a missing-tool guard" {
    run recipe_body test-unit

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"command -v bats"* ]]
    [[ "${output}" == *"bats tests/unit/"* ]]
}

@test "Justfile: shell-sources is private and expands .shellcheck-scope" {
    # The attribute must sit directly above the recipe header.
    run bash -c "grep -B1 -F 'shell-sources:' '${JUSTFILE}'"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"[private]"* ]]

    run recipe_body shell-sources
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"shopt -s globstar nullglob"* ]]
    [[ "${output}" == *".shellcheck-scope"* ]]
    # Fail loudly instead of silently expanding to nothing.
    [[ "${output}" == *"is missing"* ]]
}

@test "Justfile: tag-images is a local Podman-only helper" {
    run recipe_body tag-images

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Usage: just tag-images"* ]]
    [[ "${output}" == *"podman tag"* ]]
    # Never publish local tags to a registry.
    [[ "${output}" != *"podman push"* ]]
    [[ "${output}" != *"docker push"* ]]
    [[ "${output}" != *"skopeo copy"* ]]
}

@test "Justfile: Jenkins pipelines never call tag-images" {
    local repo_root="${BATS_TEST_DIRNAME}/../.."
    run grep -R -F 'tag-images' "${repo_root}/ci/jenkins"
    [ "${status}" -ne 0 ]
}
