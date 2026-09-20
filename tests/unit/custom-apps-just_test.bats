#!/usr/bin/env bats
# Tests for custom/ujust/custom-apps.just.
#
# Each shebang recipe body is extracted from the justfile and run against a
# `brew` stub placed first in PATH, so the Brewfile path and error propagation
# are exercised without `just`, Homebrew, or the network. CI installs only
# bats/jq, which is why the recipes are extracted instead of invoked through
# `just`.
#
# Run with: bats tests/unit/custom-apps-just_test.bats

APPS_JUST="${BATS_TEST_DIRNAME}/../../custom/ujust/custom-apps.just"
BREW_DIR="${BATS_TEST_DIRNAME}/../../custom/brew"

setup() {
    WORKDIR="${BATS_TEST_TMPDIR}"
    MOCK_BIN="${WORKDIR}/bin"
    BREW_LOG="${WORKDIR}/brew.log"

    mkdir -p "${MOCK_BIN}"
    : > "${BREW_LOG}"

    cat > "${MOCK_BIN}/brew" <<'EOF'
#!/usr/bin/bash
printf '%s\n' "$*" >> "${BREW_LOG}"
exit "${MOCK_BREW_STATUS:-0}"
EOF
    chmod +x "${MOCK_BIN}/brew"

    export BREW_LOG
}

# Print the indented body of a shebang recipe (header through last indented line).
recipe_body() {
    local recipe="$1"
    awk -v recipe="${recipe}" '
        $0 ~ ("^" recipe ":$") { in_recipe = 1; next }
        in_recipe && !found && /^    #!/ { found = 1; next }
        found && /^[^[:space:]]/ { exit }
        found { sub(/^    /, ""); print }
    ' "${APPS_JUST}"
}

# Extract a recipe body to a standalone script and run it under PATH mocks.
run_recipe() {
    local recipe="$1" out_file="${WORKDIR}/${recipe}.sh"
    recipe_body "${recipe}" > "${out_file}"
    [ -s "${out_file}" ]
    run env PATH="${MOCK_BIN}:/usr/bin:/bin" \
        BREW_LOG="${BREW_LOG}" \
        MOCK_BREW_STATUS="${MOCK_BREW_STATUS:-0}" \
        bash "${out_file}"
}

@test "install-default-apps bundles only the default Brewfile" {
    run_recipe "install-default-apps"

    [ "${status}" -eq 0 ]
    grep -qF -- "bundle --file /usr/share/ublue-os/homebrew/default.Brewfile" "${BREW_LOG}"
    [ "$(grep -cF 'bundle' "${BREW_LOG}")" -eq 1 ]
}

@test "install-default-apps propagates a failing brew bundle" {
    export MOCK_BREW_STATUS=1

    run_recipe "install-default-apps"

    [ "${status}" -ne 0 ]
}

@test "install-default-apps uses strict bash error handling" {
    run recipe_body install-default-apps

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"set -euo pipefail"* ]]
}

@test "every Brewfile referenced by a recipe exists in custom/brew" {
    local refs
    refs="$(grep -oE '/usr/share/ublue-os/homebrew/[A-Za-z0-9._-]+\.Brewfile' "${APPS_JUST}" | sort -u)"
    [ -n "${refs}" ]

    while IFS= read -r ref; do
        [ -f "${BREW_DIR}/$(basename "${ref}")" ] || {
            echo "missing local Brewfile for ${ref}"
            false
        }
    done <<< "${refs}"
}

@test "every custom-apps recipe declares a just group" {
    # ujust renders its menu by group; an ungrouped recipe disappears from it.
    local ungrouped
    ungrouped="$(awk '
        /^\[group\(/ { grouped = 1; next }
        /^[a-z][A-Za-z0-9_-]*:$/ {
            if (!grouped) print $0
            grouped = 0
            next
        }
        /^[^[:space:]]/ { grouped = 0 }
    ' "${APPS_JUST}")"
    [ -z "${ungrouped}" ]
}

@test "custom-apps.just never calls dnf5 or sudo" {
    run grep -nE 'dnf5|sudo' "${APPS_JUST}"
    [ "${status}" -ne 0 ]
}
