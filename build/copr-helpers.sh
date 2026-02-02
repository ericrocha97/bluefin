#!/usr/bin/bash
set -euo pipefail

###############################################################################
# COPR Helper Functions and Logging Utilities
###############################################################################
# These helper functions follow the @ublue-os/bluefin pattern for managing
# COPR repositories in a safe, isolated manner.
#
# This file also provides centralized logging functions used by all build
# scripts for consistent, colorful, and informative output.
###############################################################################

###############################################################################
# Logging Functions (Colored output for better readability)
###############################################################################

# Colors
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export BOLD='\033[1m'
export NC='\033[0m' # No Color

# Logging functions with timestamps
log_info() { echo -e "${BLUE}[INFO]${NC} $(date '+%H:%M:%S') $*"; }
log_success() { echo -e "${GREEN}[✓]${NC} $(date '+%H:%M:%S') $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $(date '+%H:%M:%S') $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $(date '+%H:%M:%S') $*" >&2; }
log_step() { echo -e "${CYAN}${BOLD}==>${NC} $*"; }
log_section() { echo -e "\n${BOLD}━━━ $* ━━━${NC}"; }

# Verify if a package was installed successfully
# Usage: verify_package "package-name"
verify_package() {
    local pkg="$1"
    if rpm -q "$pkg" &>/dev/null; then
        log_success "$pkg installed: $(rpm -q "$pkg")"
        return 0
    else
        log_error "$pkg installation verification failed!"
        return 1
    fi
}

# Verify multiple packages
# Usage: verify_packages "pkg1" "pkg2" "pkg3"
verify_packages() {
    local failed=0
    for pkg in "$@"; do
        if ! verify_package "$pkg"; then
            failed=$((failed + 1))
        fi
    done
    return $failed
}

###############################################################################
# COPR Helper Functions
###############################################################################

# Install packages from a COPR repository in isolated mode
# The repo is enabled only for the installation and then disabled
# Usage: copr_install_isolated "owner/repo" package1 package2 ...
copr_install_isolated() {
    local copr_name="$1"
    shift
    local packages=("$@")

    if [[ ${#packages[@]} -eq 0 ]]; then
        log_error "No packages specified for copr_install_isolated"
        return 1
    fi

    repo_id="copr:copr.fedorainfracloud.org:${copr_name//\//:}"

    log_step "Installing ${#packages[@]} packages from COPR $copr_name (isolated mode)"
    log_info "Packages: ${packages[*]}"

    log_info "Enabling COPR repository temporarily..."
    dnf5 -y copr enable "$copr_name"
    
    log_info "Disabling COPR repository (will use --enablerepo for install)..."
    dnf5 -y copr disable "$copr_name"
    
    log_info "Installing packages with isolated repo access..."
    dnf5 -y install --enablerepo="$repo_id" "${packages[@]}"

    log_success "Installed ${#packages[@]} packages from COPR $copr_name"
}
