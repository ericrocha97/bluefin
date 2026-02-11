#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Main Build Script
###############################################################################
# This script follows the @ublue-os/bluefin pattern for build scripts.
# It uses set -eoux pipefail for strict error handling and debugging.
#
# Base image: bluefin-dx already includes all DX tools, so we only need
# to copy configs and run additional scripts.
###############################################################################

# Source helper functions (includes logging utilities)
# shellcheck source=/dev/null
source /ctx/build/copr-helpers.sh

# Enable nullglob for all glob operations to prevent failures on empty matches
shopt -s nullglob

log_section "Starting Custom Build"
log_info "Base image: bluefin-dx:stable-daily"
log_info "Build timestamp: $(date '+%Y-%m-%d %H:%M:%S')"

echo "::group:: Copy Bluefin Config from Common"
log_step "Copying Bluefin configuration from @projectbluefin/common..."

# Copy just files from @projectbluefin/common (includes 00-entry.just which imports 60-custom.just)
mkdir -p /usr/share/ublue-os/just/
cp -r /ctx/oci/common/bluefin/usr/share/ublue-os/just/* /usr/share/ublue-os/just/

log_success "Bluefin just files copied to /usr/share/ublue-os/just/"
echo "::endgroup::"

echo "::group:: Copy Custom Files"
log_step "Copying custom configuration files..."

# Copy Brewfiles to standard location (if any exist)
log_info "Copying Brewfiles..."
mkdir -p /usr/share/ublue-os/homebrew/
brewfile_count=$(find /ctx/custom/brew -name '*.Brewfile' | wc -l)
if [[ $brewfile_count -gt 0 ]]; then
    find /ctx/custom/brew -name '*.Brewfile' -exec cp {} /usr/share/ublue-os/homebrew/ \;
    log_success "Copied $brewfile_count Brewfile(s) to /usr/share/ublue-os/homebrew/"
else
    log_info "No Brewfiles found to copy"
fi

# Consolidate Just Files
log_info "Consolidating custom just files..."
just_count=$(find /ctx/custom/ujust -iname '*.just' | wc -l)
if [[ $just_count -gt 0 ]]; then
    find /ctx/custom/ujust -iname '*.just' -print0 | sort -z | xargs -0 -I {} sh -c 'printf "\n\n" >> /usr/share/ublue-os/just/60-custom.just && cat {} >> /usr/share/ublue-os/just/60-custom.just'
    log_success "Consolidated $just_count custom just file(s)"
else
    log_info "No custom just files found to consolidate"
fi

# Copy Flatpak preinstall files
log_info "Copying Flatpak preinstall files..."
mkdir -p /etc/flatpak/preinstall.d/
preinstall_count=$(find /ctx/custom/flatpaks -name '*.preinstall' | wc -l)
cp /ctx/custom/flatpaks/*.preinstall /etc/flatpak/preinstall.d/
log_success "Copied $preinstall_count Flatpak preinstall file(s)"

echo "::endgroup::"

echo "::group:: Install System Packages"
log_step "Installing additional system packages..."

# COPR CLI tools for managing COPR repositories
log_info "Installing COPR CLI tools..."
dnf5 install -y copr-cli
verify_package "copr-cli"
log_success "COPR CLI tools installed"

echo "::endgroup::"

echo "::group:: System Configuration"
log_step "Configuring system services..."

# Enable/disable systemd services
log_info "Enabling podman.socket..."
systemctl enable podman.socket
log_success "podman.socket enabled"

echo "::endgroup::"

echo "::group:: Run Additional Build Scripts"
log_section "Running Additional Build Scripts"

script_count=0
for script in /ctx/build/[2-9][0-9]*-*.sh; do
    if [[ -f "${script}" ]]; then
        script_name=$(basename "${script}")
        log_step "Running ${script_name}..."
        echo ""
        /usr/bin/bash "${script}"
        echo ""
        log_success "Completed ${script_name}"
        script_count=$((script_count + 1))
    fi
done

if [[ $script_count -eq 0 ]]; then
    log_info "No additional build scripts found"
else
    log_success "Executed $script_count additional build script(s)"
fi

echo "::endgroup::"

# Restore default glob behavior
shopt -u nullglob

log_section "Build Complete"
log_success "Custom build completed successfully!"
log_info "Image ready for testing with: just build && just run-vm-qcow2"
