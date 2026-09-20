#!/usr/bin/bash

echo "::group:: ===$(basename "$0")==="

set -eoux pipefail

# CLEAN_ROOT: filesystem prefix applied to all paths.
# Defaults to "/" so the variable is never empty (satisfies SC2115).
# Set to a temp directory during unit tests.
CLEAN_ROOT="${CLEAN_ROOT:-/}"

# Revert back to upstream dnf5 defaults: do not keep downloaded packages and
# drop any version locks left behind by build-time repositories.
dnf5 config-manager setopt keepcache=0
dnf5 versionlock clear

# This comes last because we can't *ever* afford to ship fedora flatpaks on the
# image. systemctl is the only command whose failure is tolerated here, since
# the unit may already be absent (e.g. CentOS-based bases); the unit file below
# is still removed unconditionally.
systemctl disable flatpak-add-fedora-repos.service || true
systemctl mask flatpak-add-fedora-repos.service || true
rm -f "${CLEAN_ROOT}/usr/lib/systemd/system/flatpak-add-fedora-repos.service"

# Remove everything under `target` (the directory itself is left in place)
# entry by entry, never touching a mountpoint nor anything below it. This must
# not use `rm -rf` over a tree: Buildah binds active mounts into the image and
# mutating one would change its source, not the image. Files and symlinks
# (including links that point at directories) are unlinked, empty directories
# are removed depth-first, and a directory left non-empty by a preserved mount
# simply stays behind without failing the build.
safe_remove_contents() {
    local target="$1"

    # Any mountpoint at or below `target`; these subtrees must be left intact.
    # `mountpoint` follows symlinks, so a link that resolves to a mountpoint
    # (e.g. /dev/null) must never be classified as one: `! -type l` keeps all
    # links out of the mount list and they are unlinked as plain entries below.
    local mount_list=()
    mapfile -d '' -t mount_list < <(
        find "${target}" -mindepth 1 ! -type l \
            \( -exec mountpoint -q {} \; -a -print0 \)
    )

    local entries=()
    mapfile -d '' -t entries < <(find "${target}" -mindepth 1 -depth -print0)

    local entry mounted
    local skip_mounted
    for entry in "${entries[@]}"; do
        # A symlink is never a mountpoint for removal purposes even when it
        # resolves to one (mountpoint(1) follows links). The link itself is
        # always safe to unlink; the mounted target is never modified.
        if [[ ! -L "${entry}" ]] && mountpoint -q "${entry}" 2>/dev/null; then
            continue
        fi
        skip_mounted=false
        for mounted in "${mount_list[@]}"; do
            if [[ "${entry}" == "${mounted}" || "${entry}" == "${mounted}/"* ]]; then
                skip_mounted=true
                break
            fi
        done
        if [[ "${skip_mounted}" == true ]]; then
            continue
        fi
        # `! -L` keeps a symlink pointing at a directory in the removal branch;
        # `-d` alone follows the link and would leave the link unlinked.
        if [[ -d "${entry}" && ! -L "${entry}" ]]; then
            rmdir "${entry}" 2>/dev/null || true
        else
            rm -f "${entry}"
        fi
    done
}

# Clear /var subdirectories except `cache`, then clear /var/cache except the
# transient buildah cache mounts. Only top-level directories are considered
# (matching upstream), but each tree is emptied with safe_remove_contents so
# active mountpoints at any depth survive and an unexpected mount never aborts
# the build.
if [[ -d "${CLEAN_ROOT}/var" ]]; then
    var_entries=()
    mapfile -d '' -t var_entries < <(
        find "${CLEAN_ROOT}/var" -mindepth 1 -maxdepth 1 -type d ! -name cache -print0
    )
    for var_entry in "${var_entries[@]}"; do
        if [[ ! -L "${var_entry}" ]] && mountpoint -q "${var_entry}" 2>/dev/null; then
            continue
        fi
        safe_remove_contents "${var_entry}"
        rmdir "${var_entry}" 2>/dev/null || true
    done
fi
if [[ -d "${CLEAN_ROOT}/var/cache" ]]; then
    cache_entries=()
    mapfile -d '' -t cache_entries < <(
        find "${CLEAN_ROOT}/var/cache" -mindepth 1 -maxdepth 1 -type d \
            ! -name libdnf5 ! -name rpm-ostree -print0
    )
    for cache_entry in "${cache_entries[@]}"; do
        if [[ ! -L "${cache_entry}" ]] && mountpoint -q "${cache_entry}" 2>/dev/null; then
            continue
        fi
        safe_remove_contents "${cache_entry}"
        rmdir "${cache_entry}" 2>/dev/null || true
    done
fi

# Clear tmpfs-backed runtime directories without deleting the directories
# themselves. Buildah bind mounts live in these paths during RUN, so never
# touch a mountpoint nor anything below it: mutating a bind mount would affect
# its source, not the image. Remaining files, symlinks and empty directories
# are removed depth-first so children go before their parents.
for runtime_dir in tmp boot run; do
    runtime_root="${CLEAN_ROOT:?}/${runtime_dir}"
    mkdir -p "${runtime_root}"
    safe_remove_contents "${runtime_root}"
done

echo "::endgroup::"
