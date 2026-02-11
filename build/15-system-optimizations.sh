#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# System Optimizations (CachyOS configs ported for Atomic Fedora)
###############################################################################
# Based on LinuxToys optimize-cfg-ublue by psygreg
# https://github.com/psygreg/linuxtoys
#
# Installs:
#   - CachyOS sysctl tweaks (VM, network, kernel)
#   - udev rules (IO schedulers, audio PM, SATA, HPET)
#   - modprobe configs (NVIDIA, AMD, blacklist)
#   - tmpfiles configs (Transparent Huge Pages)
#   - journald size limits
#   - rpm-ostreed automatic update policy
#   - earlyoom configuration
#   - GNOME mutter check-alive-timeout
###############################################################################

# Source helper functions
# shellcheck source=build/copr-helpers.sh
# shellcheck disable=SC1091
if [[ -f /ctx/build/copr-helpers.sh ]]; then
    source /ctx/build/copr-helpers.sh
elif [[ -f "$(dirname "$0")/copr-helpers.sh" ]]; then
    source "$(dirname "$0")/copr-helpers.sh"
else
    echo "copr-helpers.sh not found" >&2
    exit 1
fi

log_section "System Optimizations"

###############################################################################
# Install CachyOS / LinuxToys Config Files
###############################################################################

echo "::group:: Install CachyOS Configs (LinuxToys)"
log_step "Installing CachyOS configuration files from LinuxToys..."

SYSTEM_FILES_DIR="/ctx/custom/system-files"

if [[ ! -d "${SYSTEM_FILES_DIR}" ]]; then
    log_error "System files directory not found: ${SYSTEM_FILES_DIR}"
    exit 1
fi

# Copy all system config files preserving directory structure
log_info "Copying system configuration files..."
cp -rv "${SYSTEM_FILES_DIR}"/usr/lib/udev/rules.d/* /usr/lib/udev/rules.d/
log_success "Copied udev rules (IO schedulers, audio PM, SATA, HPET, etc.)"

cp -rv "${SYSTEM_FILES_DIR}"/usr/lib/sysctl.d/* /usr/lib/sysctl.d/
log_success "Copied sysctl configs (CachyOS VM/network/kernel tweaks)"

cp -rv "${SYSTEM_FILES_DIR}"/usr/lib/modprobe.d/* /usr/lib/modprobe.d/
log_success "Copied modprobe configs (NVIDIA, AMD, blacklist)"

cp -rv "${SYSTEM_FILES_DIR}"/usr/lib/tmpfiles.d/* /usr/lib/tmpfiles.d/
log_success "Copied tmpfiles configs (Transparent Huge Pages)"

mkdir -p /usr/lib/systemd/journald.conf.d/
cp -rv "${SYSTEM_FILES_DIR}"/usr/lib/systemd/journald.conf.d/* /usr/lib/systemd/journald.conf.d/
log_success "Copied journald config (50M max journal size)"

# sysctl splitlock config goes to /etc
mkdir -p /etc/sysctl.d/
cp -rv "${SYSTEM_FILES_DIR}"/etc/sysctl.d/* /etc/sysctl.d/
log_success "Copied splitlock mitigation disable"

echo "::endgroup::"

###############################################################################
# Configure rpm-ostreed Automatic Updates
###############################################################################

echo "::group:: Configure Automatic Updates"
log_step "Configuring rpm-ostreed automatic update policy..."

mkdir -p /etc/rpm-ostreed.conf.d/
cp -v "${SYSTEM_FILES_DIR}"/etc/rpm-ostreed.conf.d/10-auto-updates.conf /etc/rpm-ostreed.conf.d/
log_success "AutomaticUpdatePolicy set to 'stage'"

# Enable the automatic update timer
systemctl enable rpm-ostreed-automatic.timer
log_success "rpm-ostreed-automatic.timer enabled"

echo "::endgroup::"

###############################################################################
# Configure earlyoom
###############################################################################

echo "::group:: Configure earlyoom"
log_step "Configuring earlyoom (Early OOM Daemon)..."

mkdir -p /etc/default/
cp -v "${SYSTEM_FILES_DIR}"/etc/default/earlyoom /etc/default/earlyoom
log_success "earlyoom configuration installed"

# Enable earlyoom service
systemctl enable earlyoom
log_success "earlyoom service enabled"

echo "::endgroup::"

###############################################################################
# Install GNOME GSettings Override
###############################################################################

echo "::group:: Install GNOME Tweaks"
log_step "Installing GNOME GSettings overrides..."

mkdir -p /usr/share/glib-2.0/schemas/
cp -v "${SYSTEM_FILES_DIR}"/usr/share/glib-2.0/schemas/99-custom.gschema.override \
    /usr/share/glib-2.0/schemas/

# Recompile GSettings schemas to apply overrides
log_info "Recompiling GSettings schemas..."
glib-compile-schemas /usr/share/glib-2.0/schemas/
log_success "GNOME check-alive-timeout set to 20000ms"

echo "::endgroup::"

###############################################################################
# Summary
###############################################################################

log_section "System Optimizations Complete"
log_success "All LinuxToys/CachyOS optimizations applied:"
log_info "  ✓ CachyOS sysctl tweaks (swappiness, vfs_cache_pressure, dirty bytes, etc.)"
log_info "  ✓ IO scheduler rules (BFQ for HDD, mq-deadline for SSD, none for NVMe)"
log_info "  ✓ Audio power management rules"
log_info "  ✓ NVIDIA/AMD modprobe optimizations"
log_info "  ✓ Transparent Huge Pages (defer+madvise, shrinker at 80%)"
log_info "  ✓ Journal size limited to 50MB"
log_info "  ✓ Automatic updates (stage policy)"
log_info "  ✓ earlyoom enabled (5% memory/swap threshold)"
log_info "  ✓ GNOME mutter check-alive-timeout = 20s"
