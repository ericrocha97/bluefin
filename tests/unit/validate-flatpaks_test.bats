#!/usr/bin/env bats
# Unit tests for build/validate-flatpaks.sh.
# A mock `flatpak` is placed first in PATH so the tests never touch the real
# flathub remote and can assert exactly which remote-info lookups are made.
# Run with: bats tests/unit/validate-flatpaks_test.bats

VALIDATOR="${BATS_TEST_DIRNAME}/../../build/validate-flatpaks.sh"

setup() {
    TEST_ROOT="${BATS_TEST_TMPDIR}"
    FLATPAK_DIR="${TEST_ROOT}/flatpaks"
    STUB_BIN="${TEST_ROOT}/bin"
    FLATPAK_LOG="${TEST_ROOT}/flatpak.log"

    mkdir -p "${FLATPAK_DIR}" "${STUB_BIN}"
    : > "${FLATPAK_LOG}"

    export PATH="${STUB_BIN}:${PATH}"
    export FLATPAK_LOG

    # The mock resolves the app id as the last argument, so it stays correct
    # whether or not the validator inserts a `--` option terminator.
    cat > "${STUB_BIN}/flatpak" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${FLATPAK_LOG}"
last=""
for arg in "$@"; do last="${arg}"; done
if [[ "${1:-}" == "remote-info" && "${last}" == "org.example.Missing" ]]; then
    echo "error: No remote ref found" >&2
    exit 1
fi
exit 0
EOF
    chmod +x "${STUB_BIN}/flatpak"
}

run_validator() {
    run bash "${VALIDATOR}" "${1:-${FLATPAK_DIR}}"
}

@test "validate-flatpaks: accepts a section with a Branch key" {
    cat > "${FLATPAK_DIR}/default.preinstall" <<'EOF'
[Flatpak Preinstall org.mozilla.firefox]
Branch=stable
EOF

    run_validator
    [ "${status}" -eq 0 ]
    grep -q -- "remote-info --user flathub -- org.mozilla.firefox" "${FLATPAK_LOG}"
}

@test "validate-flatpaks: discovers preinstall files in subdirectories" {
    mkdir -p "${FLATPAK_DIR}/nested"
    cat > "${FLATPAK_DIR}/nested/extra.preinstall" <<'EOF'
[Flatpak Preinstall org.gnome.Calculator]
Branch=stable
EOF

    run_validator
    [ "${status}" -eq 0 ]
    grep -q -- "remote-info --user flathub -- org.gnome.Calculator" "${FLATPAK_LOG}"
}

@test "validate-flatpaks: fails when the root directory is absent" {
    run_validator "${TEST_ROOT}/does-not-exist"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"Flatpak directory does not exist"* ]]
    [ ! -s "${FLATPAK_LOG}" ]
}

@test "validate-flatpaks: fails when no preinstall files are present" {
    run_validator
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"No .preinstall files found"* ]]
}

@test "validate-flatpaks: rejects a section without a Branch key" {
    cat > "${FLATPAK_DIR}/default.preinstall" <<'EOF'
[Flatpak Preinstall org.mozilla.firefox]
EOF

    run_validator
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"missing Branch= key"* ]]
    ! grep -q -- "remote-info" "${FLATPAK_LOG}"
}

@test "validate-flatpaks: fails when an app is not on flathub" {
    cat > "${FLATPAK_DIR}/default.preinstall" <<'EOF'
[Flatpak Preinstall org.example.Missing]
Branch=stable
EOF

    run_validator
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"not on flathub"* ]]
    grep -q -- "remote-info --user flathub -- org.example.Missing" "${FLATPAK_LOG}"
}

@test "validate-flatpaks: validates multiple sections independently" {
    cat > "${FLATPAK_DIR}/default.preinstall" <<'EOF'
[Flatpak Preinstall org.mozilla.firefox]
Branch=stable

[Flatpak Preinstall org.example.Missing]
Branch=stable
EOF

    run_validator
    [ "${status}" -ne 0 ]
    grep -q -- "remote-info --user flathub -- org.mozilla.firefox" "${FLATPAK_LOG}"
    grep -q -- "remote-info --user flathub -- org.example.Missing" "${FLATPAK_LOG}"
}

@test "validate-flatpaks: fails when flatpak is not installed" {
    rm -f "${STUB_BIN}/flatpak"
    local bash_bin
    bash_bin="$(command -v bash)"

    run env PATH="${STUB_BIN}" "${bash_bin}" "${VALIDATOR}" "${FLATPAK_DIR}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"flatpak is required"* ]]
}

@test "validate-flatpaks: rejects an app id beginning with a dash" {
    cat > "${FLATPAK_DIR}/default.preinstall" <<'EOF'
[Flatpak Preinstall --help]
Branch=stable
EOF

    run_validator
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"invalid app id"* ]]
    ! grep -q -- "remote-info" "${FLATPAK_LOG}"
}

@test "validate-flatpaks: accepts a CRLF preinstall file" {
    printf '[Flatpak Preinstall org.mozilla.firefox]\r\nBranch=stable\r\n' \
        > "${FLATPAK_DIR}/default.preinstall"

    run_validator
    [ "${status}" -eq 0 ]
    grep -q -- "remote-info --user flathub -- org.mozilla.firefox" "${FLATPAK_LOG}"
}

@test "validate-flatpaks: enforces Branch= in a CRLF file" {
    printf '[Flatpak Preinstall org.mozilla.firefox]\r\n' \
        > "${FLATPAK_DIR}/default.preinstall"

    run_validator
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"missing Branch= key"* ]]
    ! grep -q -- "remote-info" "${FLATPAK_LOG}"
}

@test "validate-flatpaks: fails on an empty preinstall file" {
    : > "${FLATPAK_DIR}/default.preinstall"

    run_validator
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"no [Flatpak Preinstall"* ]]
    ! grep -q -- "remote-info" "${FLATPAK_LOG}"
}

@test "validate-flatpaks: fails on a comments-only preinstall file" {
    cat > "${FLATPAK_DIR}/default.preinstall" <<'EOF'
# nothing to install here
# [Flatpak Preinstall org.mozilla.firefox]
EOF

    run_validator
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"no [Flatpak Preinstall"* ]]
    ! grep -q -- "remote-info" "${FLATPAK_LOG}"
}

@test "validate-flatpaks: fails when a file has no recognizable section" {
    cat > "${FLATPAK_DIR}/default.preinstall" <<'EOF'
 [Flatpak Preinstall org.mozilla.firefox]
Branch=stable
EOF

    run_validator
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"no [Flatpak Preinstall"* ]]
    ! grep -q -- "remote-info" "${FLATPAK_LOG}"
}
