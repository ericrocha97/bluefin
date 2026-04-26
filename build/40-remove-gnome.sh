#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Remove GNOME Desktop and Enable COSMIC Greeter
###############################################################################
# COSMIC is installed by 30-cosmic-desktop.sh before this script runs.
# Keep this script conservative: remove user-facing GNOME desktop/session pieces,
# not shared GTK/GLib libraries that other applications may still need.
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

log_section "Removing GNOME Desktop"

###############################################################################
# Display Manager Transition
###############################################################################

echo "::group:: Disable GDM"
log_step "Disabling GDM before package removal..."

if systemctl list-unit-files gdm.service --no-legend 2>/dev/null | grep -q '^gdm.service'; then
    systemctl disable gdm.service || log_warn "Unable to disable gdm.service before removal"
    log_success "gdm.service disabled"
else
    log_info "gdm.service unit is not present"
fi

echo "::endgroup::"

###############################################################################
# Remove GNOME Packages
###############################################################################

echo "::group:: Remove GNOME packages"
log_step "Preparing conservative GNOME desktop package removal list..."

GNOME_PACKAGES=(
    gdm
    gnome-shell
    gnome-session
    gnome-session-wayland-session
    gnome-session-xsession
    gnome-classic-session
    gnome-control-center
    gnome-software
    gnome-initial-setup
    gnome-tour
    gnome-terminal
    gnome-text-editor
    gnome-system-monitor
    gnome-disk-utility
    gnome-calendar
    gnome-contacts
    gnome-clocks
    gnome-logs
    gnome-maps
    gnome-weather
    gnome-connections
    gnome-remote-desktop
    gnome-user-docs
    gnome-user-share
    gnome-browser-connector
    nautilus
    mutter
    xdg-desktop-portal-gnome
)

installed_packages=()
absent_packages=()

for pkg in "${GNOME_PACKAGES[@]}"; do
    if rpm -q "$pkg" &>/dev/null; then
        installed_packages+=("$pkg")
    else
        absent_packages+=("$pkg")
    fi
done

if [[ ${#absent_packages[@]} -gt 0 ]]; then
    log_info "GNOME removal candidates not installed: ${absent_packages[*]}"
fi

if [[ ${#installed_packages[@]} -gt 0 ]]; then
    log_info "Removing installed GNOME packages: ${installed_packages[*]}"
    dnf5 remove -y "${installed_packages[@]}"
    log_success "Installed GNOME package candidates removed"
else
    log_info "No GNOME package candidates were installed"
fi

echo "::endgroup::"

###############################################################################
# Remove Leftover GNOME Session Files
###############################################################################

echo "::group:: Remove GNOME session files"
log_step "Removing leftover GNOME session files..."

rm -f \
    /usr/share/wayland-sessions/gnome.desktop \
    /usr/share/wayland-sessions/gnome-classic.desktop \
    /usr/share/xsessions/gnome.desktop \
    /usr/share/xsessions/gnome-classic.desktop

log_success "GNOME session file cleanup complete"
echo "::endgroup::"

###############################################################################
# Enable COSMIC Greeter
###############################################################################

echo "::group:: Enable COSMIC Greeter"
log_step "Enabling cosmic-greeter.service..."

if systemctl list-unit-files cosmic-greeter.service --no-legend 2>/dev/null | grep -q '^cosmic-greeter.service'; then
    systemctl enable cosmic-greeter.service
    log_success "cosmic-greeter.service enabled"
else
    log_error "cosmic-greeter.service unit not found"
    log_info "Available greeter unit files:"
    systemctl list-unit-files '*greeter*' --no-legend 2>/dev/null || true
    exit 1
fi

echo "::endgroup::"

###############################################################################
# Verify COSMIC-only State
###############################################################################

echo "::group:: Verify COSMIC-only desktop state"
log_step "Verifying COSMIC session and GNOME removal..."

if [[ ! -f /usr/share/wayland-sessions/cosmic.desktop ]]; then
    log_error "COSMIC session file is missing after GNOME removal"
    exit 1
fi

shopt -s nullglob
gnome_sessions=(
    /usr/share/wayland-sessions/gnome*.desktop
    /usr/share/xsessions/gnome*.desktop
)
shopt -u nullglob

if [[ ${#gnome_sessions[@]} -gt 0 ]]; then
    log_error "GNOME session files remain: ${gnome_sessions[*]}"
    exit 1
fi

critical_packages=(gdm gnome-shell gnome-session)
critical_failure=0
for pkg in "${critical_packages[@]}"; do
    if rpm -q "$pkg" &>/dev/null; then
        log_error "Critical GNOME package still installed: $pkg"
        critical_failure=1
    fi
done

if [[ $critical_failure -eq 1 ]]; then
    exit 1
fi

log_success "COSMIC session is present and GNOME sessions are absent"
echo "::endgroup::"

###############################################################################
# Summary
###############################################################################

log_section "GNOME Removal Complete"
log_success "COSMIC Greeter is enabled and GNOME desktop sessions are removed"
