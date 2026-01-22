#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Install COSMIC Desktop (System76) on base-main
###############################################################################
# This script installs COSMIC from the System76 COPR repository.
# Base image is ghcr.io/ublue-os/base-main:latest (no desktop included).
###############################################################################

# Source helper functions
# shellcheck source=/dev/null
if ! source /ctx/build/copr-helpers.sh; then
    echo "Error: Failed to source /ctx/build/copr-helpers.sh; cannot proceed with COPR installation." >&2
    exit 1
fi

echo "::group:: Install COSMIC Desktop"

# Install COSMIC desktop from System76's COPR
# Using isolated pattern to prevent COPR from persisting
copr_install_isolated "ryanabx/cosmic-epoch" \
    cosmic-session \
    cosmic-greeter \
    cosmic-comp \
    cosmic-panel \
    cosmic-launcher \
    cosmic-applets \
    cosmic-settings \
    cosmic-files \
    cosmic-edit \
    cosmic-term \
    cosmic-workspaces \
    xdg-desktop-portal-cosmic

echo "COSMIC desktop installed successfully"
echo "::endgroup::"

echo "::group:: Configure Display Manager"

# Enable cosmic-greeter (COSMIC's display manager)
if [[ -f /usr/lib/systemd/system/cosmic-greeter.service || -f /etc/systemd/system/cosmic-greeter.service ]]; then
    systemctl enable cosmic-greeter
elif [[ -f /etc/systemd/system/display-manager.service ]]; then
    systemctl enable display-manager.service
    echo "Warning: cosmic-greeter service unit not found; enabled display-manager.service instead." >&2
else
    echo "Warning: no display manager service unit found; skipping enable step." >&2
fi

echo "Display manager configured"
echo "::endgroup::"

echo "COSMIC desktop installation complete!"
