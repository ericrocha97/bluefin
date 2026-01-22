#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Main Build Script
###############################################################################
# This script follows the @ublue-os/bluefin pattern for build scripts.
# It uses set -eoux pipefail for strict error handling and debugging.
###############################################################################

# Source helper functions
# shellcheck source=/dev/null
source /ctx/build/copr-helpers.sh

# Enable nullglob for all glob operations to prevent failures on empty matches
shopt -s nullglob

echo "::group:: Copy Bluefin Config from Common"

# Copy just files from @projectbluefin/common (includes 00-entry.just which imports 60-custom.just)
mkdir -p /usr/share/ublue-os/just/
shopt -s nullglob
cp -r /ctx/oci/common/bluefin/usr/share/ublue-os/just/* /usr/share/ublue-os/just/
shopt -u nullglob

echo "::endgroup::"

echo "::group:: Copy Custom Files"

# Copy Brewfiles to standard location
mkdir -p /usr/share/ublue-os/homebrew/
cp /ctx/custom/brew/*.Brewfile /usr/share/ublue-os/homebrew/

# Consolidate Just Files
find /ctx/custom/ujust -iname '*.just' -exec printf "\n\n" \; -exec cat {} \; >> /usr/share/ublue-os/just/60-custom.just

# Copy Flatpak preinstall files
mkdir -p /etc/flatpak/preinstall.d/
cp /ctx/custom/flatpaks/*.preinstall /etc/flatpak/preinstall.d/

echo "::endgroup::"

echo "::group:: Install Packages"

# Install packages using dnf5
# Example: dnf5 install -y tmux

# DX tooling (containers, virtualization, build essentials)
dnf5 install -y \
	git \
	gcc \
	gcc-c++ \
	make \
	cmake \
	python3-devel \
	openssl-devel \
	curl \
	zsh \
	fish \
	podman \
	podman-docker \
	podman-compose \
	toolbox \
	distrobox \
	libvirt \
	virt-manager \
	qemu-kvm \
	cockpit \
	cockpit-machines \
	flatpak-builder \
	jq

# Bluefin DX CLI tools (install what is available in Fedora)
CLI_PACKAGES=(
	atuin
	bat
	bash-preexec
	chezmoi
	direnv
	dysk
	eza
	fastfetch
	fd-find
	gh
	glab
	htop
	ripgrep
	shellcheck
	starship
	stress-ng
	tealdeer
	television
	tmux
	trash-cli
	ugrep
	uutils-coreutils
	yq
	zoxide
)

for pkg in "${CLI_PACKAGES[@]}"; do
	if dnf5 install -y "${pkg}"; then
		echo "Installed ${pkg}"
	else
		echo "Skipping ${pkg} (not available in repos)"
	fi
done

# Example using COPR with isolated pattern:
# copr_install_isolated "ublue-os/staging" package-name

echo "::endgroup::"

echo "::group:: Fastfetch Defaults"

# Copy Bluefin fastfetch defaults from @projectbluefin/common
mkdir -p /usr/share/ublue-os /usr/bin /etc/profile.d /usr/share/fish/vendor_conf.d

if [[ -f /ctx/oci/common/bluefin/usr/share/ublue-os/fastfetch.jsonc ]]; then
	cp -f /ctx/oci/common/bluefin/usr/share/ublue-os/fastfetch.jsonc /usr/share/ublue-os/fastfetch.jsonc
fi

for fastfetch_bin in ublue-fastfetch ublue-bling-fastfetch; do
	if [[ -f /ctx/oci/common/shared/usr/bin/${fastfetch_bin} ]]; then
		cp -f /ctx/oci/common/shared/usr/bin/${fastfetch_bin} /usr/bin/${fastfetch_bin}
		chmod +x /usr/bin/${fastfetch_bin}
	fi
done

if [[ -f /ctx/oci/common/shared/etc/profile.d/ublue-fastfetch.sh ]]; then
	cp -f /ctx/oci/common/shared/etc/profile.d/ublue-fastfetch.sh /etc/profile.d/ublue-fastfetch.sh
fi

if [[ -f /ctx/oci/common/shared/usr/share/fish/vendor_conf.d/ublue-fastfetch.fish ]]; then
	cp -f /ctx/oci/common/shared/usr/share/fish/vendor_conf.d/ublue-fastfetch.fish /usr/share/fish/vendor_conf.d/ublue-fastfetch.fish
fi

# Populate counts used by fastfetch (fallback to 0 on failure)
mkdir -p /usr/share/ublue-os
if command -v curl >/dev/null 2>&1; then
	if ! curl -fsSL https://raw.githubusercontent.com/ublue-os/countme/main/badge-endpoints/bluefin.json | jq -r ".message" > /usr/share/ublue-os/fastfetch-user-count; then
		echo "0" > /usr/share/ublue-os/fastfetch-user-count
	fi
	if ! curl -fsSL "https://flathub.org/api/v2/stats/io.github.kolunmi.Bazaar?all=false&days=1" | jq -r ".installs_last_7_days" > /usr/share/ublue-os/bazaar-install-count; then
		echo "0" > /usr/share/ublue-os/bazaar-install-count
	fi
else
	echo "0" > /usr/share/ublue-os/fastfetch-user-count
	echo "0" > /usr/share/ublue-os/bazaar-install-count
fi

echo "::endgroup::"

echo "::group:: System Configuration"

# Enable/disable systemd services
systemctl enable podman.socket
# Enable optional services if available
if systemctl list-unit-files > /dev/null 2>&1; then
	if systemctl list-unit-files | grep -q '^cockpit.socket'; then
		systemctl enable cockpit.socket
	fi
	if systemctl list-unit-files | grep -q '^libvirtd.service'; then
		systemctl enable libvirtd
	fi
fi
# Example: systemctl mask unwanted-service

echo "::endgroup::"

echo "::group:: Run Additional Build Scripts"

for script in /ctx/build/[2-9][0-9]*-*.sh; do
	if [[ -f "${script}" ]]; then
		echo "Running ${script}"
		/usr/bin/bash "${script}"
	fi
done

echo "::endgroup::"

# Restore default glob behavior
shopt -u nullglob

echo "Custom build complete!"
