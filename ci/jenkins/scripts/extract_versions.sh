#!/usr/bin/env bash

set -euo pipefail

: "${CURRENT_MANIFEST:?CURRENT_MANIFEST is required}"
: "${OUTPUT_FILE:?OUTPUT_FILE is required}"

PREVIOUS_MANIFEST="${PREVIOUS_MANIFEST:-}"

get_version_from_manifest() {
    local file="$1"
    local package="$2"

    if [[ ! -f "$file" ]]; then
        return 0
    fi

    awk -F '\t' -v pkg="$package" '$1==pkg {print $2; exit}' "$file"
}

normalize_version() {
    local version="$1"

    if [[ -z "$version" ]]; then
        printf '%s' "unknown"
    else
        printf '%s' "$version"
    fi
}

tracked_packages=(
    code-insiders
    warp-terminal
    vicinae
    cosmic-session
    cosmic-comp
    cosmic-panel
    cosmic-launcher
    cosmic-settings
    cosmic-files
    cosmic-edit
    cosmic-term
    cosmic-store
    cosmic-player
    cosmic-screenshot
    xdg-desktop-portal-cosmic
)

kernel_version="$(normalize_version "$(get_version_from_manifest "$CURRENT_MANIFEST" kernel)")"
vscode_version="$(normalize_version "$(get_version_from_manifest "$CURRENT_MANIFEST" code-insiders)")"
warp_version="$(normalize_version "$(get_version_from_manifest "$CURRENT_MANIFEST" warp-terminal)")"
vicinae_version="$(normalize_version "$(get_version_from_manifest "$CURRENT_MANIFEST" vicinae)")"
cosmic_session_version="$(normalize_version "$(get_version_from_manifest "$CURRENT_MANIFEST" cosmic-session)")"

changelog_lines=()
if [[ -n "$PREVIOUS_MANIFEST" && -f "$PREVIOUS_MANIFEST" ]]; then
    for pkg in "${tracked_packages[@]}"; do
        old_version="$(get_version_from_manifest "$PREVIOUS_MANIFEST" "$pkg")"
        new_version="$(get_version_from_manifest "$CURRENT_MANIFEST" "$pkg")"
        if [[ -n "$old_version" && -n "$new_version" && "$old_version" != "$new_version" ]]; then
            changelog_lines+=("- ${pkg}: ${old_version} -> ${new_version}")
        fi
    done
fi

if [[ ${#changelog_lines[@]} -eq 0 ]]; then
    changelog_lines+=("- No tracked package version changes detected.")
fi

{
    echo "kernel_version=$kernel_version"
    echo "vscode_version=$vscode_version"
    echo "warp_version=$warp_version"
    echo "vicinae_version=$vicinae_version"
    echo "cosmic_session_version=$cosmic_session_version"
    echo "changelog<<EOF"
    printf '%s\n' "${changelog_lines[@]}"
    echo "EOF"
} >"$OUTPUT_FILE"
