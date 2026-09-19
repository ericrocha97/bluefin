#!/usr/bin/env bats
# Unit tests for build/copr-helpers.sh.
#
# The library is sourced inside an isolated `bash -c` for every test so its
# top-level `set -euo pipefail` never leaks into the BATS process. A `dnf5`
# and an `rpm` stub are placed first in PATH, so the isolated-enable ordering,
# the repo-id translation and the verification helpers are all exercised
# without a network, a real COPR repository or an image build.
#
# Run with: bats tests/unit/copr-helpers_test.bats

COPR_HELPERS_LIB="${BATS_TEST_DIRNAME}/../../build/copr-helpers.sh"

setup() {
    TEST_ROOT="${BATS_TEST_TMPDIR}"
    STUB_BIN="${TEST_ROOT}/bin"
    DNF5_LOG="${TEST_ROOT}/dnf5.log"
    RPM_LOG="${TEST_ROOT}/rpm.log"

    mkdir -p "${STUB_BIN}"
    : > "${DNF5_LOG}"
    : > "${RPM_LOG}"

    export PATH="${STUB_BIN}:${PATH}"
    export COPR_HELPERS_LIB DNF5_LOG RPM_LOG
    unset DNF5_FAIL_MATCH DNF5_FAIL_CODE RPM_FAIL_MATCH COPR_VERIFY_PACKAGES

    cat > "${STUB_BIN}/dnf5" <<'EOF'
#!/usr/bin/bash
printf '%s\n' "$*" >> "${DNF5_LOG}"
if [[ -n "${DNF5_FAIL_MATCH:-}" && "$*" == *"${DNF5_FAIL_MATCH}"* ]]; then
    exit "${DNF5_FAIL_CODE:-1}"
fi
exit 0
EOF
    chmod +x "${STUB_BIN}/dnf5"

    cat > "${STUB_BIN}/rpm" <<'EOF'
#!/usr/bin/bash
printf '%s\n' "$*" >> "${RPM_LOG}"
if [[ -n "${RPM_FAIL_MATCH:-}" && "$*" == *"${RPM_FAIL_MATCH}"* ]]; then
    exit 1
fi
if [[ "$*" == *"--qf"* ]]; then
    echo "stub-1.0-1.x86_64"
fi
exit 0
EOF
    chmod +x "${STUB_BIN}/rpm"
}

@test "copr_install_isolated: enables, disables, then installs from the repo id" {
    run bash -c 'set -euo pipefail; source "$COPR_HELPERS_LIB"; copr_install_isolated atim/starship starship'
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Installing 1 packages from COPR atim/starship (isolated mode)"* ]]
    [[ "${output}" == *"Installed 1 packages from COPR atim/starship"* ]]

    mapfile -t calls < "${DNF5_LOG}"
    [ "${#calls[@]}" -eq 3 ]
    [ "${calls[0]}" = "-y copr enable atim/starship" ]
    [ "${calls[1]}" = "-y copr disable atim/starship" ]
    [ "${calls[2]}" = "-y install --enablerepo=copr:copr.fedorainfracloud.org:atim:starship starship" ]
}

@test "copr_install_isolated: disables the repo before installing so it stays off by default" {
    run bash -c 'set -euo pipefail; source "$COPR_HELPERS_LIB"; copr_install_isolated ublue-os/staging ublue-update'
    [ "${status}" -eq 0 ]

    mapfile -t calls < "${DNF5_LOG}"
    disable_index=-1
    install_index=-1
    for i in "${!calls[@]}"; do
        [[ "${calls[${i}]}" == *"copr disable"* ]] && disable_index="${i}"
        [[ "${calls[${i}]}" == *" install "* ]] && install_index="${i}"
    done
    [ "${disable_index}" -ge 0 ]
    [ "${install_index}" -ge 0 ]
    [ "${disable_index}" -lt "${install_index}" ]
}

@test "copr_install_isolated: installs multiple packages in a single dnf5 transaction" {
    run bash -c 'set -euo pipefail; source "$COPR_HELPERS_LIB"; copr_install_isolated atim/starship starship zsh fish'
    [ "${status}" -eq 0 ]

    mapfile -t calls < "${DNF5_LOG}"
    [ "${#calls[@]}" -eq 3 ]
    [ "${calls[2]}" = "-y install --enablerepo=copr:copr.fedorainfracloud.org:atim:starship starship zsh fish" ]
}

@test "copr_install_isolated: translates every slash in the copr name into the repo id" {
    run bash -c 'set -euo pipefail; source "$COPR_HELPERS_LIB"; copr_install_isolated owner/group/project pkg'
    [ "${status}" -eq 0 ]

    mapfile -t calls < "${DNF5_LOG}"
    [[ "${calls[2]}" == *"--enablerepo=copr:copr.fedorainfracloud.org:owner:group:project"* ]]
    [[ "${calls[2]}" != *"owner/group/project "* ]]
}

@test "copr_install_isolated: fails when no packages are supplied" {
    run bash -c 'set -euo pipefail; source "$COPR_HELPERS_LIB"; copr_install_isolated atim/starship'
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"No packages specified for copr_install_isolated"* ]]
    [ ! -s "${DNF5_LOG}" ]
}

@test "copr_install_isolated: propagates a dnf5 install failure" {
    export DNF5_FAIL_MATCH=" install "
    export DNF5_FAIL_CODE=23

    run bash -c 'set -euo pipefail; source "$COPR_HELPERS_LIB"; copr_install_isolated atim/starship starship'
    [ "${status}" -eq 23 ]
    [[ "${output}" == *"Installing 1 packages from COPR atim/starship (isolated mode)"* ]]
    [[ "${output}" != *"Installed 1 packages"* ]]
}

@test "copr_install_isolated: propagates a dnf5 copr enable failure without installing" {
    export DNF5_FAIL_MATCH="copr enable"
    export DNF5_FAIL_CODE=7

    run bash -c 'set -euo pipefail; source "$COPR_HELPERS_LIB"; copr_install_isolated atim/starship starship'
    [ "${status}" -eq 7 ]

    mapfile -t calls < "${DNF5_LOG}"
    [ "${#calls[@]}" -eq 1 ]
    [ "${calls[0]}" = "-y copr enable atim/starship" ]
}

@test "copr-helpers.sh: sourcing the library performs no dnf5 calls" {
    run bash -c 'source "$COPR_HELPERS_LIB"'
    [ "${status}" -eq 0 ]
    [ ! -s "${DNF5_LOG}" ]
}

@test "logging helpers tag their level and message" {
    run bash -c 'source "$COPR_HELPERS_LIB"; log_info alpha; log_success beta; log_warn gamma'
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"[INFO]"*"alpha"* ]]
    [[ "${output}" == *"[✓]"*"beta"* ]]
    [[ "${output}" == *"[WARN]"*"gamma"* ]]
}

@test "log_error writes the error tag and message" {
    run bash -c 'source "$COPR_HELPERS_LIB"; log_error boom'
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"[ERROR]"*"boom"* ]]
}

@test "verify_package: reports the installed rpm metadata on success" {
    run bash -c 'set -euo pipefail; source "$COPR_HELPERS_LIB"; verify_package stub'
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Installed: stub-1.0-1.x86_64"* ]]
}

@test "verify_package: fails when the rpm query fails" {
    export RPM_FAIL_MATCH="missing"

    run bash -c 'set -euo pipefail; source "$COPR_HELPERS_LIB"; verify_package missing'
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"missing installation verification failed"* ]]
}

@test "verify_packages: fails when any package fails to verify" {
    export RPM_FAIL_MATCH="missing"

    run bash -c 'set -euo pipefail; source "$COPR_HELPERS_LIB"; verify_packages good missing'
    [ "${status}" -eq 1 ]
}

@test "COPR_VERIFY_PACKAGES=true warns but still succeeds when verification fails" {
    export COPR_VERIFY_PACKAGES=true
    export RPM_FAIL_MATCH="demo"

    run bash -c 'set -euo pipefail; source "$COPR_HELPERS_LIB"; copr_install_isolated atim/starship demo'
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Could not verify version for demo"* ]]
    [[ "${output}" == *"Installed 1 packages from COPR atim/starship"* ]]
}
