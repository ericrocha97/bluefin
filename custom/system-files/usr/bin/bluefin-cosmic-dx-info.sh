#!/usr/bin/bash
###############################################################################
# bluefin-cosmic-dx-info.sh - Custom image info for fastfetch
###############################################################################
# Reads the build manifest and displays custom image information.
# Used by fastfetch.jsonc via the "command" module type.
#
# Usage:
#   bluefin-cosmic-dx-info.sh                # Output image name + version
#   bluefin-cosmic-dx-info.sh --release      # Output GitHub release tag
#   bluefin-cosmic-dx-info.sh --build-date   # Output formatted build date
#   bluefin-cosmic-dx-info.sh --shell        # Output user's actual shell + version
###############################################################################

MANIFEST="/usr/share/bluefin-cosmic-dx/manifest.json"
IMAGE_NAME="bluefin-cosmic-dx"

case "${1:-}" in
    --release)
        if [[ -f "$MANIFEST" ]] && command -v jq &>/dev/null; then
            tag=$(jq -r '.release_tag // "unknown"' "$MANIFEST" 2>/dev/null)
            echo "${tag}"
        else
            echo "unknown"
        fi
        ;;
    --build-date)
        if [[ -f "$MANIFEST" ]] && command -v jq &>/dev/null; then
            build_date=$(jq -r '.build_date_utc // empty' "$MANIFEST" 2>/dev/null)
            if [[ -n "$build_date" ]]; then
                date -d "$build_date" +'Built %b %d %G %H:%M UTC' 2>/dev/null || echo "unknown"
            else
                echo "unknown"
            fi
        else
            echo "unknown"
        fi
        ;;
    --shell)
        # Detect the user's actual shell by walking up the process tree.
        # The call chain is:
        #   terminal → user_shell → ublue-fastfetch (bash) → fastfetch → this_script (bash)
        # We climb the tree and keep the LAST shell found (closest to the terminal).
        shell_found=""
        pid=$$
        while [[ -n "$pid" && "$pid" != "1" && "$pid" != "0" ]]; do
            pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
            [[ -z "$pid" || "$pid" == "0" ]] && break
            comm=$(ps -o comm= -p "$pid" 2>/dev/null | tr -d ' ')
            case "$comm" in
                bash|zsh|fish|dash|tcsh|csh|ksh|nu|nushell|elvish|xonsh)
                    shell_found="$comm"
                    ;;
            esac
        done

        # Fallback to login shell if nothing found
        if [[ -z "$shell_found" ]]; then
            shell_path=$(getent passwd "$(whoami)" 2>/dev/null | cut -d: -f7)
            shell_found=$(basename "${shell_path:-bash}")
        fi

        # Get version
        shell_path=$(command -v "$shell_found" 2>/dev/null || echo "$shell_found")
        version=$("$shell_path" --version 2>&1 | head -1 | grep -oP '[0-9]+\.[0-9]+\.?[0-9]*' | head -1)
        echo "${shell_found} ${version}"
        ;;
    *)
        # Default: show image name and base OS version
        if [[ -f "$MANIFEST" ]] && command -v jq &>/dev/null; then
            os_version=$(jq -r '.os_release.version // "unknown"' "$MANIFEST" 2>/dev/null)
            echo "${IMAGE_NAME} (${os_version})"
        else
            echo "${IMAGE_NAME}"
        fi
        ;;
esac
