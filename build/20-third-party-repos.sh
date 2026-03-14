#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Install VSCode Insiders and Warp Terminal from Official Repositories
###############################################################################
# Conventions:
# - Use dnf5 exclusively
# - Always use -y for non-interactive installs
# - Remove repo files after installation (repos don't work at runtime)
###############################################################################

# Source helper functions (includes logging utilities)
# shellcheck source=/dev/null
source /ctx/build/copr-helpers.sh

log_section "Installing Third-Party Software"

###############################################################################
# VSCode Insiders
###############################################################################

echo "::group:: Install VSCode Insiders"
log_step "Installing Visual Studio Code Insiders..."

log_info "Adding Microsoft VSCode repository..."
cat > /etc/yum.repos.d/vscode.repo << 'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

log_info "Importing Microsoft GPG key..."
rpm --import https://packages.microsoft.com/keys/microsoft.asc

log_info "Installing code-insiders package..."
dnf5 install -y code-insiders

# Verify installation
verify_package "code-insiders"

log_info "Cleaning up Microsoft repository file..."
rm -f /etc/yum.repos.d/vscode.repo

log_success "VSCode Insiders installation complete"
echo "::endgroup::"

###############################################################################
# Warp Terminal
###############################################################################

echo "::group:: Install Warp Terminal"
log_step "Installing Warp Terminal..."

log_info "Adding Warp Terminal repository..."
cat > /etc/yum.repos.d/warpdotdev.repo << 'EOF'
[warpdotdev]
name=warpdotdev
baseurl=https://releases.warp.dev/linux/rpm/stable
enabled=1
gpgcheck=1
gpgkey=https://releases.warp.dev/linux/keys/warp.asc
EOF

log_info "Importing Warp GPG key..."
rpm --import https://releases.warp.dev/linux/keys/warp.asc

log_info "Installing warp-terminal package..."
dnf5 install -y warp-terminal

# Verify installation
verify_package "warp-terminal"

log_info "Cleaning up Warp repository file..."
rm -f /etc/yum.repos.d/warpdotdev.repo

log_success "Warp Terminal installation complete"
echo "::endgroup::"

###############################################################################
# Vicinae
###############################################################################

echo "::group:: Install Vicinae"
log_step "Installing Vicinae..."

# Terra repo definition pinned to terrapkg/subatomic-repos@6672af7a7125aef3400606dc9da174cfe423a0a1
# Note: repository contents are still rolling; this only pins the repo file.
log_info "Adding Terra repository (Bazzite-compatible)..."
install -m 0644 /ctx/build/terra.repo /etc/yum.repos.d/terra.repo

log_info "Importing Terra GPG key..."
releasever=$(rpm --eval '%{fedora}' 2>/dev/null || true)
if [[ -z "$releasever" ]]; then
    releasever=$(grep -E '^VERSION_ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
fi
rpm --import "https://repos.fyralabs.com/terra${releasever}/key.asc"

log_info "Installing vicinae package..."
dnf5 install -y vicinae

# Verify installation
verify_package "vicinae"

log_info "Cleaning up Terra repository file..."
rm -f /etc/yum.repos.d/terra.repo

log_success "Vicinae installation complete"
echo "::endgroup::"

log_section "Third-Party Software Installation Complete"
log_success "All third-party applications installed successfully"
