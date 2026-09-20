#!/usr/bin/env bats
# Static contract for the Docker/Podman build context filter.
#
# The Containerfile's ctx stage copies only `build/` and `custom/` from the
# context, and `build/*.sh` reads `/ctx/build/**` plus `/ctx/custom/**` while
# the image is built. These tests read `.dockerignore`; they never run
# podman/docker and never start a build.
#
# Run with: bats tests/unit/dockerignore_test.bats

REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
DOCKERIGNORE="${REPO_ROOT}/.dockerignore"

# Patterns only, comments and blank lines stripped.
ignore_patterns() {
    grep -v '^[[:space:]]*#' "${DOCKERIGNORE}" | grep -v '^[[:space:]]*$'
}

@test ".dockerignore exists and is non-empty" {
    [ -f "${DOCKERIGNORE}" ]
    [ -s "${DOCKERIGNORE}" ]
}

@test ".dockerignore excludes the context the Containerfile does not read" {
    local pattern
    for pattern in '.git' '.github' 'docs' 'tests' 'ci' 'iso' 'output' '.agents' '.superpowers'; do
        run grep -Fx -- "${pattern}" "${DOCKERIGNORE}"
        [ "${status}" -eq 0 ] || {
            echo "expected .dockerignore to exclude: ${pattern}"
            false
        }
    done
}

@test ".dockerignore never hides build/ or custom/" {
    # Comments may mention the directories; only ignore directives count.
    run grep -E '(^|/)(build|custom)(/|$)' <(ignore_patterns)
    [ "${status}" -ne 0 ]
}

@test ".dockerignore never hides Containerfile or Justfile" {
    # Explicit must-keep assertions: Containerfile defines the build and
    # Justfile drives local tooling, so neither may be filtered out.
    local path
    for path in 'Containerfile' 'Justfile'; do
        run grep -E "(^|/)${path}(/|\$)" <(ignore_patterns)
        [ "${status}" -ne 0 ] || {
            echo "expected .dockerignore to keep: ${path}"
            false
        }
    done
}

@test ".dockerignore has no negation rules that could re-include ignored files" {
    run grep -E '^[[:space:]]*!' <(ignore_patterns)
    [ "${status}" -ne 0 ]
}

@test ".dockerignore keeps local artifacts and the public key out of the context" {
    run grep -Fx -- 'cosign.pub' "${DOCKERIGNORE}"
    [ "${status}" -eq 0 ]

    run grep -Fx -- '*.log' "${DOCKERIGNORE}"
    [ "${status}" -eq 0 ]

    run grep -Fx -- '_build-*' "${DOCKERIGNORE}"
    [ "${status}" -eq 0 ]
}
