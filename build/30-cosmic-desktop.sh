#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Install COSMIC Desktop (System76)
###############################################################################
# This script installs COSMIC from the System76 COPR repository.
# GNOME removal and display-manager switching happen later in 40-remove-gnome.sh.
###############################################################################

# Source helper functions (includes logging utilities)
# shellcheck source=build/copr-helpers.sh
# shellcheck disable=SC1091
if [[ -f /ctx/build/copr-helpers.sh ]]; then
    source /ctx/build/copr-helpers.sh
elif [[ -f "$(dirname "$0")/copr-helpers.sh" ]]; then
    source "$(dirname "$0")/copr-helpers.sh"
else
    echo "copr-helpers.sh not found in /ctx/build or script directory" >&2
    exit 1
fi

log_section "Installing COSMIC Desktop"
log_info "COSMIC will be installed as the only desktop session in the final image"

###############################################################################
# Install COSMIC Packages
###############################################################################

echo "::group:: Install COSMIC Desktop"

COSMIC_PACKAGES=(
    cosmic-session
    cosmic-greeter
    cosmic-comp
    cosmic-panel
    cosmic-launcher
    cosmic-applets
    cosmic-settings
    cosmic-files
    cosmic-edit
    cosmic-term
    cosmic-store
    cosmic-player
    cosmic-screenshot
    cosmic-bg
    cosmic-wallpapers
    cosmic-icon-theme
    cosmic-notifications
    cosmic-osd
    cosmic-app-library
    cosmic-workspaces
    xdg-desktop-portal-cosmic
)

log_step "Installing COSMIC packages from COPR ryanabx/cosmic-epoch..."
log_info "Packages to install: ${COSMIC_PACKAGES[*]}"

copr_install_isolated "ryanabx/cosmic-epoch" "${COSMIC_PACKAGES[@]}"

echo "::endgroup::"

###############################################################################
# Verify Installation
###############################################################################

echo "::group:: Verify COSMIC Installation"
log_step "Verifying COSMIC package installation..."

verification_failed=0
for pkg in "${COSMIC_PACKAGES[@]}"; do
    if ! verify_package "$pkg"; then
        verification_failed=1
    fi
done

if [[ $verification_failed -eq 1 ]]; then
    log_error "Some COSMIC packages failed verification!"
    exit 1
fi

if [[ -f /usr/share/wayland-sessions/cosmic.desktop ]]; then
    log_success "COSMIC session registered: /usr/share/wayland-sessions/cosmic.desktop"
else
    log_error "COSMIC session file not found at /usr/share/wayland-sessions/cosmic.desktop"
    log_info "Available COSMIC desktop files:"
    find /usr/share -name "cosmic*.desktop" 2>/dev/null || true
    exit 1
fi

log_success "All COSMIC packages verified successfully"
echo "::endgroup::"

###############################################################################
# Summary
###############################################################################

log_section "COSMIC Desktop Installation Complete"
log_success "COSMIC desktop installed successfully"
log_info "GNOME removal and COSMIC Greeter activation will run in 40-remove-gnome.sh"
