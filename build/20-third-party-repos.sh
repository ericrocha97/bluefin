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

echo "::group:: Install VSCode Insiders"

# Add Microsoft VSCode RPM repository
cat > /etc/yum.repos.d/vscode.repo << 'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

# Import Microsoft GPG key
rpm --import https://packages.microsoft.com/keys/microsoft.asc

# Install VSCode Insiders
dnf5 install -y code-insiders

# Clean up repo file
rm -f /etc/yum.repos.d/vscode.repo

echo "VSCode Insiders installed successfully"
echo "::endgroup::"

echo "::group:: Install Warp Terminal"

# Add Warp RPM repository
cat > /etc/yum.repos.d/warpdotdev.repo << 'EOF'
[warpdotdev]
name=warpdotdev
baseurl=https://releases.warp.dev/linux/rpm/stable
enabled=1
gpgcheck=1
gpgkey=https://releases.warp.dev/linux/keys/warp.asc
EOF

# Import Warp GPG key
rpm --import https://releases.warp.dev/linux/keys/warp.asc

# Install Warp Terminal
dnf5 install -y warp-terminal

# Clean up repo file
rm -f /etc/yum.repos.d/warpdotdev.repo

echo "Warp Terminal installed successfully"
echo "::endgroup::"
