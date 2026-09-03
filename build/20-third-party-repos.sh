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
# OpenLogi
###############################################################################

echo "::group:: Install OpenLogi"
log_step "Installing OpenLogi (latest release)..."

log_info "Fetching latest OpenLogi release download URL from GitHub API..."
RPM_URL=$(curl -sSL https://api.github.com/repos/AprilNEA/OpenLogi/releases/latest \
    | jq -r '.assets[] | select(.name | test("openlogi-.*-linux-amd64\\.rpm$")) | .browser_download_url' \
    | head -n 1)

if [[ -z "${RPM_URL}" || "${RPM_URL}" == "null" ]]; then
    log_warn "Failed to resolve latest OpenLogi RPM URL via GitHub API. Aborting OpenLogi install."
    exit 1
fi

log_info "Downloading RPM from ${RPM_URL}..."
curl -sSL -o /tmp/openlogi-latest.rpm "${RPM_URL}"

log_info "Installing OpenLogi via dnf5..."
dnf5 install -y /tmp/openlogi-latest.rpm

# Verify installation
verify_package "openlogi"

log_info "Cleaning up temporary files..."
rm -f /tmp/openlogi-latest.rpm

log_success "OpenLogi installation complete"
echo "::endgroup::"

###############################################################################
# Vicinae
###############################################################################

echo "::group:: Install Vicinae"
log_step "Installing Vicinae..."

log_info "Installing official Terra release package..."
if ! dnf5 install -y --nogpgcheck --repofrompath "terra,https://repos.fyralabs.com/terra\$releasever" terra-release; then
    log_warn "Terra release package unavailable (checksum/metadata issue). Will fall back to COPR for vicinae..."
fi

log_info "Installing vicinae package from Terra..."
if ! dnf5 install -y vicinae; then
    log_warn "Terra installation failed (metadata/mirror issue). Falling back to COPR..."

    dnf5 clean all

    log_info "Enabling Vicinae COPR with dependency repositories..."
    dnf5 -y copr enable quadratech188/vicinae

    log_info "Installing vicinae from COPR..."
    dnf5 install -y vicinae

    log_info "Disabling Vicinae COPR repositories after installation..."
    dnf5 -y copr disable quadratech188/vicinae || true
fi

# Verify installation
verify_package "vicinae"

log_success "Vicinae installation complete"
echo "::endgroup::"

log_section "Third-Party Software Installation Complete"
log_success "All third-party applications installed successfully"
