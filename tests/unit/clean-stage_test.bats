#!/usr/bin/env bats
# Unit tests for build/clean-stage.sh.
# The script honours CLEAN_ROOT as a filesystem prefix, so every destructive
# operation is exercised against a sandbox directory instead of the host.
# Run with: bats tests/unit/clean-stage_test.bats

CLEAN_STAGE="${BATS_TEST_DIRNAME}/../../build/clean-stage.sh"

setup() {
    TEST_ROOT="${BATS_TEST_TMPDIR}"
    STUB_BIN="${TEST_ROOT}/stub-bin"
    DNF5_LOG="${TEST_ROOT}/logs/dnf5.log"
    SYSTEMCTL_LOG="${TEST_ROOT}/logs/systemctl.log"
    SANDBOX="${TEST_ROOT}/root"

    mkdir -p "${STUB_BIN}" "${TEST_ROOT}/logs"

    # Minimal filesystem layout the script expects to operate on.
    mkdir -p "${SANDBOX}/usr/lib/systemd/system"
    mkdir -p "${SANDBOX}/var/cache/libdnf5"
    mkdir -p "${SANDBOX}/var/cache/rpm-ostree"
    mkdir -p "${SANDBOX}/var/cache/dnf"
    mkdir -p "${SANDBOX}/var/tmp/leftover"
    mkdir -p "${SANDBOX}/run/dnf"
    mkdir -p "${SANDBOX}/tmp/leftover"
    mkdir -p "${SANDBOX}/boot/grub2"
    touch "${SANDBOX}/usr/lib/systemd/system/flatpak-add-fedora-repos.service"
    touch "${SANDBOX}/var/tmp/leftover/file"
    touch "${SANDBOX}/run/dnf/state"
    touch "${SANDBOX}/tmp/leftover/file"
    touch "${SANDBOX}/boot/grub2/grub.cfg"

    export PATH="${STUB_BIN}:${PATH}"
    export CLEAN_ROOT="${SANDBOX}"
    export DNF5_LOG
    export SYSTEMCTL_LOG

    cat > "${STUB_BIN}/dnf5" <<'EOF'
#!/usr/bin/bash
printf '%s\n' "$*" >> "${DNF5_LOG}"
exit 0
EOF
    chmod +x "${STUB_BIN}/dnf5"

    cat > "${STUB_BIN}/systemctl" <<'EOF'
#!/usr/bin/bash
printf '%s\n' "$*" >> "${SYSTEMCTL_LOG}"
exit 0
EOF
    chmod +x "${STUB_BIN}/systemctl"

    # mountpoint(1) is not meaningful inside the sandbox; default to "not a
    # mountpoint" so the script takes its normal removal path.
    cat > "${STUB_BIN}/mountpoint" <<'EOF'
#!/usr/bin/bash
exit 1
EOF
    chmod +x "${STUB_BIN}/mountpoint"
}

teardown() {
    rm -rf "${TEST_ROOT}"
}

run_clean_stage() {
    run bash "${CLEAN_STAGE}"
}

@test "clean-stage: completes successfully against a sandbox root" {
    run_clean_stage
    [ "${status}" -eq 0 ]
}

@test "clean-stage: restores dnf5 upstream defaults and clears versionlock" {
    run_clean_stage
    [ "${status}" -eq 0 ]

    mapfile -t calls < "${DNF5_LOG}"
    [ "${#calls[@]}" -eq 2 ]
    [ "${calls[0]}" = "config-manager setopt keepcache=0" ]
    [ "${calls[1]}" = "versionlock clear" ]
}

@test "clean-stage: disables and masks the fedora flatpak repo service" {
    run_clean_stage
    [ "${status}" -eq 0 ]

    mapfile -t calls < "${SYSTEMCTL_LOG}"
    [ "${#calls[@]}" -eq 2 ]
    [ "${calls[0]}" = "disable flatpak-add-fedora-repos.service" ]
    [ "${calls[1]}" = "mask flatpak-add-fedora-repos.service" ]
}

@test "clean-stage: removes the flatpak-add-fedora-repos unit file" {
    [ -f "${SANDBOX}/usr/lib/systemd/system/flatpak-add-fedora-repos.service" ]

    run_clean_stage
    [ "${status}" -eq 0 ]
    [ ! -e "${SANDBOX}/usr/lib/systemd/system/flatpak-add-fedora-repos.service" ]
}

@test "clean-stage: removes /var subdirectories other than cache" {
    run_clean_stage
    [ "${status}" -eq 0 ]
    [ ! -e "${SANDBOX}/var/tmp" ]
    [ -d "${SANDBOX}/var/cache" ]
}

@test "clean-stage: keeps libdnf5 and rpm-ostree cache dirs, drops the rest" {
    run_clean_stage
    [ "${status}" -eq 0 ]
    [ -d "${SANDBOX}/var/cache/libdnf5" ]
    [ -d "${SANDBOX}/var/cache/rpm-ostree" ]
    [ ! -e "${SANDBOX}/var/cache/dnf" ]
}

@test "clean-stage: empties tmp, boot and run but keeps the directories" {
    run_clean_stage
    [ "${status}" -eq 0 ]
    [ -d "${SANDBOX}/tmp" ]
    [ -d "${SANDBOX}/boot" ]
    [ -d "${SANDBOX}/run" ]
    [ ! -e "${SANDBOX}/tmp/leftover" ]
    [ ! -e "${SANDBOX}/boot/grub2" ]
    [ ! -e "${SANDBOX}/run/dnf" ]
}

@test "clean-stage: creates tmp and boot when they are absent" {
    rm -rf "${SANDBOX:?}/tmp" "${SANDBOX:?}/boot"

    run_clean_stage
    [ "${status}" -eq 0 ]
    [ -d "${SANDBOX}/tmp" ]
    [ -d "${SANDBOX}/boot" ]
}

@test "clean-stage: tolerates missing paths" {
    rm -rf "${SANDBOX:?}/var" "${SANDBOX:?}/tmp" "${SANDBOX:?}/boot" "${SANDBOX:?}/run"

    run_clean_stage
    [ "${status}" -eq 0 ]
    [ ! -e "${SANDBOX}/var" ]
    [ -d "${SANDBOX}/tmp" ]
    [ -d "${SANDBOX}/boot" ]
    [ -d "${SANDBOX}/run" ]
}

@test "clean-stage: skips entries that are mountpoints" {
    mkdir -p "${SANDBOX}/run/mounted"
    touch "${SANDBOX}/run/mounted/keepme"
    mkdir -p "${SANDBOX}/tmp/mounted"
    touch "${SANDBOX}/tmp/mounted/keepme"
    mkdir -p "${SANDBOX}/boot/mounted"
    touch "${SANDBOX}/boot/mounted/keepme"

    cat > "${STUB_BIN}/mountpoint" <<EOF
#!/usr/bin/bash
# Treat only the three seeded paths as mountpoints.
case "\$2" in
    "${SANDBOX}/run/mounted"|"${SANDBOX}/tmp/mounted"|"${SANDBOX}/boot/mounted") exit 0 ;;
esac
exit 1
EOF
    chmod +x "${STUB_BIN}/mountpoint"

    run_clean_stage
    [ "${status}" -eq 0 ]
    [ -d "${SANDBOX}/run/mounted" ]
    [ -f "${SANDBOX}/run/mounted/keepme" ]
    [ -d "${SANDBOX}/tmp/mounted" ]
    [ -d "${SANDBOX}/boot/mounted" ]
}

@test "clean-stage: skips mountpoints under var and var/cache" {
    mkdir -p "${SANDBOX}/var/lib/mounted"
    touch "${SANDBOX}/var/lib/mounted/persistent"
    mkdir -p "${SANDBOX}/var/cache/mounted-cache"
    touch "${SANDBOX}/var/cache/mounted-cache/persistent"

    cat > "${STUB_BIN}/mountpoint" <<EOF
#!/usr/bin/bash
case "\$2" in
    "${SANDBOX}/var/lib/mounted"|"${SANDBOX}/var/cache/mounted-cache") exit 0 ;;
esac
exit 1
EOF
    chmod +x "${STUB_BIN}/mountpoint"

    run_clean_stage
    [ "${status}" -eq 0 ]
    [ -d "${SANDBOX}/var/lib/mounted" ]
    [ -f "${SANDBOX}/var/lib/mounted/persistent" ]
    [ -d "${SANDBOX}/var/cache/mounted-cache" ]
    [ -f "${SANDBOX}/var/cache/mounted-cache/persistent" ]
}

@test "clean-stage: prunes nested var mountpoints without deleting siblings" {
    mkdir -p "${SANDBOX}/var/lib/state/deep"
    touch "${SANDBOX}/var/lib/state/deep/persistent"
    mkdir -p "${SANDBOX}/var/lib/other"
    touch "${SANDBOX}/var/lib/other/residue"

    cat > "${STUB_BIN}/mountpoint" <<EOF
#!/usr/bin/bash
case "\$2" in
    "${SANDBOX}/var/lib/state") exit 0 ;;
esac
exit 1
EOF
    chmod +x "${STUB_BIN}/mountpoint"

    run_clean_stage
    [ "${status}" -eq 0 ]
    [ -d "${SANDBOX}/var/lib/state" ]
    [ -f "${SANDBOX}/var/lib/state/deep/persistent" ]
    [ ! -e "${SANDBOX}/var/lib/other" ]
    [ -d "${SANDBOX}/var/lib" ]
}

@test "clean-stage: removes symlinks that point at directories" {
    mkdir -p "${SANDBOX}/tmp/realdir" "${SANDBOX}/boot/realdir" "${SANDBOX}/run/realdir"
    ln -s "${SANDBOX}/tmp/realdir" "${SANDBOX}/tmp/linkdir"
    ln -s "${SANDBOX}/boot/realdir" "${SANDBOX}/boot/linkdir"
    ln -s "${SANDBOX}/run/realdir" "${SANDBOX}/run/linkdir"

    run_clean_stage
    [ "${status}" -eq 0 ]
    [ ! -L "${SANDBOX}/tmp/linkdir" ]
    [ ! -L "${SANDBOX}/boot/linkdir" ]
    [ ! -L "${SANDBOX}/run/linkdir" ]
    [ ! -e "${SANDBOX}/tmp/realdir" ]
    [ ! -e "${SANDBOX}/boot/realdir" ]
    [ ! -e "${SANDBOX}/run/realdir" ]
}

@test "clean-stage: removes symlinks that resolve to mountpoints, keeps the mount" {
    # Mirrors the real image residue: /var/lib/greetd contains a symlink to
    # /dev/null. `mountpoint -q` follows symlinks and reports the *link* as a
    # mountpoint, so the link must still be unlinked without touching /dev/null.
    mkdir -p "${SANDBOX}/var/lib/greetd/.config/systemd/user"
    ln -s /dev/null \
        "${SANDBOX}/var/lib/greetd/.config/systemd/user/xdg-desktop-portal.service"

    # A genuine mountpoint whose sub-tree must survive untouched.
    mkdir -p "${SANDBOX}/run/mounted"
    touch "${SANDBOX}/run/mounted/keepme"

    cat > "${STUB_BIN}/mountpoint" <<EOF
#!/usr/bin/bash
# mountpoint(1) follows symlinks: report the /dev/null link as a mountpoint,
# plus the real mount, and nothing else.
case "\$2" in
    "${SANDBOX}/var/lib/greetd/.config/systemd/user/xdg-desktop-portal.service"|"${SANDBOX}/run/mounted") exit 0 ;;
esac
exit 1
EOF
    chmod +x "${STUB_BIN}/mountpoint"

    run_clean_stage
    [ "${status}" -eq 0 ]
    [ ! -L "${SANDBOX}/var/lib/greetd/.config/systemd/user/xdg-desktop-portal.service" ]
    [ ! -e "${SANDBOX}/var/lib/greetd" ]
    [ -d "${SANDBOX}/run/mounted" ]
    [ -f "${SANDBOX}/run/mounted/keepme" ]
}

@test "clean-stage: tolerates systemctl failure and still removes the unit" {
    cat > "${STUB_BIN}/systemctl" <<'EOF'
#!/usr/bin/bash
printf '%s\n' "$*" >> "${SYSTEMCTL_LOG}"
exit 1
EOF
    chmod +x "${STUB_BIN}/systemctl"

    run_clean_stage
    [ "${status}" -eq 0 ]
    [ ! -e "${SANDBOX}/usr/lib/systemd/system/flatpak-add-fedora-repos.service" ]
}

@test "clean-stage: does not tolerate dnf5 failure" {
    cat > "${STUB_BIN}/dnf5" <<'EOF'
#!/usr/bin/bash
exit 1
EOF
    chmod +x "${STUB_BIN}/dnf5"

    run_clean_stage
    [ "${status}" -ne 0 ]
}

@test "clean-stage: is idempotent across repeated runs" {
    run_clean_stage
    [ "${status}" -eq 0 ]

    run_clean_stage
    [ "${status}" -eq 0 ]
}
