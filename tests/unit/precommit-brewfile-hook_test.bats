#!/usr/bin/env bats
# Contract gate for .pre-commit-config.yaml and the Brewfiles it guards.
#
# build/validate-brewfiles.sh is the single implementation of Brewfile
# validation: Brewfiles are a Ruby DSL, so handing a repository Brewfile to
# `brew bundle` / `brew bundle check` would evaluate PR-controlled code. A local
# pre-commit hook must stay a caller of that script.
#
# These tests are textual: they never run pre-commit or Homebrew.
#
# Run with: bats tests/unit/precommit-brewfile-hook_test.bats

CONFIG="${BATS_TEST_DIRNAME}/../../.pre-commit-config.yaml"
SCRIPT="${BATS_TEST_DIRNAME}/../../build/validate-brewfiles.sh"
JUSTFILE="${BATS_TEST_DIRNAME}/../../Justfile"
BREW_DIR="${BATS_TEST_DIRNAME}/../../custom/brew"
UJUST_DIR="${BATS_TEST_DIRNAME}/../../custom/ujust"

# The `entry:` line of the local validate-brewfiles hook.
hook_entry() {
    awk '
        /^[[:space:]]*-[[:space:]]*id:[[:space:]]*validate-brewfiles[[:space:]]*$/ { found = 1; next }
        found && /^[[:space:]]*entry:/ { sub(/^[[:space:]]*entry:[[:space:]]*/, ""); print; exit }
        found && /^[[:space:]]*-[[:space:]]*id:/ { exit }
    ' "${CONFIG}"
}

@test "pre-commit config exists and declares a validate-brewfiles hook" {
    [ -f "${CONFIG}" ]
    run hook_entry
    [ "${status}" -eq 0 ]
    [ -n "${output}" ]
}

@test "validate-brewfiles hook delegates to build/validate-brewfiles.sh" {
    run hook_entry
    [ "${status}" -eq 0 ]
    [[ "${output}" == "bash build/validate-brewfiles.sh custom/brew" ]]
}

@test "the delegated script is present and is the same one the Justfile uses" {
    [ -f "${SCRIPT}" ]
    run grep -F 'bash build/validate-brewfiles.sh custom/brew' "${JUSTFILE}"
    [ "${status}" -eq 0 ]
}

@test "the hook scopes itself to Brewfiles and does not pass filenames" {
    run grep -F "'^custom/brew/.*\\.Brewfile.*\$'" "${CONFIG}"
    [ "${status}" -eq 0 ]

    run grep -F 'pass_filenames: false' "${CONFIG}"
    [ "${status}" -eq 0 ]
}

@test "no pre-commit hook feeds a repository Brewfile to brew bundle" {
    # Any `brew bundle` (with or without `check`) in the config would be a
    # second implementation; the only legitimate `brew bundle` call lives
    # inside build/validate-brewfiles.sh, on a generated literal-taps file.
    run bash -c "grep -v '^[[:space:]]*#' '${CONFIG}' | grep -n 'brew[[:space:]]\\+bundle'"
    [ "${status}" -ne 0 ]
}

@test "no pre-commit hook globs custom/brew Brewfiles into a shell loop" {
    run bash -c "grep -v '^[[:space:]]*#' '${CONFIG}' | grep -n 'custom/brew/\\*'"
    [ "${status}" -ne 0 ]
}

@test "every Brewfile referenced by a ujust recipe exists in custom/brew" {
    # README files document the pattern with example Brewfiles that users are
    # meant to create; only real recipes must point at a shipped file.
    local refs
    refs="$(find "${UJUST_DIR}" -name '*.just' -exec grep -hoE '/usr/share/ublue-os/homebrew/[A-Za-z0-9._-]+\.Brewfile' {} + | sort -u)"
    [ -n "${refs}" ]

    while IFS= read -r ref; do
        [ -f "${BREW_DIR}/$(basename "${ref}")" ] || {
            echo "missing local Brewfile for ${ref}"
            false
        }
    done <<< "${refs}"
}
