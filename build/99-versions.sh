#!/usr/bin/bash

set -euo pipefail

###############################################################################
# Write a version manifest inside the image
###############################################################################
# This manifest captures versions for key packages that change frequently.
###############################################################################

# Source helper functions (includes logging utilities)
# shellcheck source=/dev/null
source /ctx/build/copr-helpers.sh

manifest_dir="/usr/share/bluefin-cosmic-dx"
manifest_path="${manifest_dir}/manifest.json"

log_section "Writing version manifest"

mkdir -p "${manifest_dir}"

json_escape() {
    local value="$1"
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\n'/\\n}
    printf '%s' "$value"
}

get_rpm_version() {
    local package="$1"
    local version
    version=$(rpm -q --qf '%{VERSION}-%{RELEASE}' "$package" 2>/dev/null || true)
    if [[ -z "$version" ]]; then
        printf '%s' "not-installed"
        return 0
    fi
    printf '%s' "$version"
}

get_os_release_value() {
    local key="$1"
    local value
    value=$(grep -E "^${key}=" /etc/os-release 2>/dev/null | head -n 1 | cut -d= -f2- | tr -d '"')
    printf '%s' "$value"
}

build_date_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
os_name=$(json_escape "$(get_os_release_value NAME)")
os_version=$(json_escape "$(get_os_release_value VERSION)")
os_pretty_name=$(json_escape "$(get_os_release_value PRETTY_NAME)")

cat > "${manifest_path}" <<EOF
{
  "build_date_utc": "${build_date_utc}",
  "os_release": {
    "name": "${os_name}",
    "version": "${os_version}",
    "pretty_name": "${os_pretty_name}"
  },
  "packages": {
    "kernel": "$(json_escape "$(get_rpm_version kernel)")",
    "copr-cli": "$(json_escape "$(get_rpm_version copr-cli)")",
    "code-insiders": "$(json_escape "$(get_rpm_version code-insiders)")",
    "warp-terminal": "$(json_escape "$(get_rpm_version warp-terminal)")",
    "cosmic-session": "$(json_escape "$(get_rpm_version cosmic-session)")",
    "cosmic-greeter": "$(json_escape "$(get_rpm_version cosmic-greeter)")",
    "cosmic-comp": "$(json_escape "$(get_rpm_version cosmic-comp)")",
    "cosmic-panel": "$(json_escape "$(get_rpm_version cosmic-panel)")",
    "cosmic-launcher": "$(json_escape "$(get_rpm_version cosmic-launcher)")",
    "cosmic-applets": "$(json_escape "$(get_rpm_version cosmic-applets)")",
    "cosmic-settings": "$(json_escape "$(get_rpm_version cosmic-settings)")",
    "cosmic-files": "$(json_escape "$(get_rpm_version cosmic-files)")",
    "cosmic-edit": "$(json_escape "$(get_rpm_version cosmic-edit)")",
    "cosmic-term": "$(json_escape "$(get_rpm_version cosmic-term)")",
    "cosmic-store": "$(json_escape "$(get_rpm_version cosmic-store)")",
    "cosmic-player": "$(json_escape "$(get_rpm_version cosmic-player)")",
    "cosmic-screenshot": "$(json_escape "$(get_rpm_version cosmic-screenshot)")",
    "cosmic-bg": "$(json_escape "$(get_rpm_version cosmic-bg)")",
    "cosmic-wallpapers": "$(json_escape "$(get_rpm_version cosmic-wallpapers)")",
    "cosmic-icon-theme": "$(json_escape "$(get_rpm_version cosmic-icon-theme)")",
    "cosmic-notifications": "$(json_escape "$(get_rpm_version cosmic-notifications)")",
    "cosmic-osd": "$(json_escape "$(get_rpm_version cosmic-osd)")",
    "cosmic-app-library": "$(json_escape "$(get_rpm_version cosmic-app-library)")",
    "cosmic-workspaces": "$(json_escape "$(get_rpm_version cosmic-workspaces)")",
    "xdg-desktop-portal-cosmic": "$(json_escape "$(get_rpm_version xdg-desktop-portal-cosmic)")"
  }
}
EOF

chmod 0644 "${manifest_path}"
log_success "Manifest written to ${manifest_path}"
