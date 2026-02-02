#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Install COSMIC Desktop (System76) alongside GNOME
###############################################################################
# This script installs COSMIC from the System76 COPR repository.
# Base image is bluefin-dx:stable-daily which includes GNOME.
# COSMIC is installed as an additional desktop option, selectable at login.
###############################################################################

# Source helper functions (includes logging utilities)
# shellcheck source=/dev/null
source /ctx/build/copr-helpers.sh

log_section "Installing COSMIC Desktop"
log_info "COSMIC will be installed alongside GNOME (dual desktop setup)"

###############################################################################
# Install COSMIC Packages
###############################################################################

echo "::group:: Install COSMIC Desktop"

# Define COSMIC packages to install
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
    cosmic-workspaces
    xdg-desktop-portal-cosmic
)

log_step "Installing COSMIC packages from COPR ryanabx/cosmic-epoch..."
log_info "Packages to install: ${COSMIC_PACKAGES[*]}"

# Install COSMIC desktop from System76's COPR
# Using isolated pattern to prevent COPR from persisting
copr_install_isolated "ryanabx/cosmic-epoch" "${COSMIC_PACKAGES[@]}"

echo "::endgroup::"

###############################################################################
# Verify Installation
###############################################################################

echo "::group:: Verify COSMIC Installation"
log_step "Verifying COSMIC package installation..."

# Verify critical packages
critical_packages=(
    cosmic-session
    cosmic-comp
    cosmic-panel
    cosmic-settings
)

verification_failed=0
for pkg in "${critical_packages[@]}"; do
    if ! verify_package "$pkg"; then
        verification_failed=1
    fi
done

if [[ $verification_failed -eq 1 ]]; then
    log_error "Some critical COSMIC packages failed verification!"
    exit 1
fi

log_success "All critical COSMIC packages verified"
echo "::endgroup::"

###############################################################################
# Configure Display Manager
###############################################################################

echo "::group:: Configure Display Manager"
log_step "Configuring display manager for dual desktop support..."

# Keep GDM as default display manager (comes with bluefin-dx)
# User can choose between GNOME and COSMIC at login screen
log_info "GDM will remain as default display manager"
log_info "Users can select COSMIC or GNOME from the gear icon at login"

# Verify COSMIC session file exists
if [[ -f /usr/share/wayland-sessions/cosmic.desktop ]]; then
    log_success "COSMIC session registered: /usr/share/wayland-sessions/cosmic.desktop"
else
    log_warn "COSMIC session file not found at expected location"
    log_info "Checking alternative locations..."
    find /usr/share -name "cosmic*.desktop" 2>/dev/null | while read -r session_file; do
        log_info "Found session file: $session_file"
    done
fi

# List available sessions
log_info "Available desktop sessions:"
if [[ -d /usr/share/wayland-sessions ]]; then
    for session in /usr/share/wayland-sessions/*.desktop; do
        if [[ -f "$session" ]]; then
            session_name=$(grep -E "^Name=" "$session" 2>/dev/null | cut -d= -f2 || basename "$session")
            log_info "  - $session_name ($(basename "$session"))"
        fi
    done
fi

echo "::endgroup::"

###############################################################################
# Summary
###############################################################################

log_section "COSMIC Desktop Installation Complete"
log_success "COSMIC desktop installed successfully as secondary desktop"
log_info ""
log_info "Desktop selection instructions:"
log_info "  1. At the GDM login screen, click the gear icon (⚙️)"
log_info "  2. Select 'COSMIC' or 'GNOME' session"
log_info "  3. Enter your password to log in"
log_info ""
log_info "To switch default display manager to COSMIC Greeter (optional):"
log_info "  sudo systemctl disable gdm && sudo systemctl enable cosmic-greeter"
