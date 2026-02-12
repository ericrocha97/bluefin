#!/usr/bin/bash
###############################################################################
# bluefin-cosmic-dx-info.sh - Custom image info for fastfetch
###############################################################################
# Reads the build manifest and displays custom image information.
# Used by fastfetch.jsonc via the "command" module type.
#
# Usage:
#   bluefin-cosmic-dx-info.sh             # Output image name + version
#   bluefin-cosmic-dx-info.sh --cosmic-version  # Output COSMIC session version
###############################################################################

MANIFEST="/usr/share/bluefin-cosmic-dx/manifest.json"
IMAGE_NAME="bluefin-cosmic-dx"

case "${1:-}" in
    --cosmic-version)
        if [[ -f "$MANIFEST" ]] && command -v jq &>/dev/null; then
            version=$(jq -r '.packages."cosmic-session" // "unknown"' "$MANIFEST" 2>/dev/null)
            # Strip the release suffix for cleaner display (e.g., "1.0.0-1.fc42" -> "1.0.0")
            echo "${version%%-*}"
        else
            echo "unknown"
        fi
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
