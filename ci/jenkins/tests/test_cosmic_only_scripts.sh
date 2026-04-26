#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/assert.sh"

COSMIC_SCRIPT="$REPO_ROOT/build/30-cosmic-desktop.sh"
REMOVE_GNOME_SCRIPT="$REPO_ROOT/build/40-remove-gnome.sh"
OPTIMIZATIONS_SCRIPT="$REPO_ROOT/build/15-system-optimizations.sh"
README_EN="$REPO_ROOT/README.md"
README_PT="$REPO_ROOT/README.pt-BR.md"
BUILD_README="$REPO_ROOT/build/README.md"

assert_file_contains "$COSMIC_SCRIPT" 'log_section "Installing COSMIC Desktop"'
assert_file_contains "$COSMIC_SCRIPT" "cosmic-greeter"
assert_file_contains "$COSMIC_SCRIPT" "xdg-desktop-portal-cosmic"

for stale_text in "alongside GNOME" "dual desktop" "GDM will remain" "gear icon"; do
    if grep -Fqi -- "$stale_text" "$COSMIC_SCRIPT"; then
        fail "Unexpected stale COSMIC install wording in build/30-cosmic-desktop.sh: $stale_text"
    fi
done

assert_file_contains "$REMOVE_GNOME_SCRIPT" "GNOME_PACKAGES=("
assert_file_contains "$REMOVE_GNOME_SCRIPT" "cosmic-greeter.service"
assert_file_contains "$REMOVE_GNOME_SCRIPT" "dnf5 remove -y"
assert_file_contains "$REMOVE_GNOME_SCRIPT" "/usr/share/wayland-sessions/gnome.desktop"
assert_file_contains "$REMOVE_GNOME_SCRIPT" "/usr/share/wayland-sessions/cosmic.desktop"

for stale_text in "GNOME GSettings" "glib-compile-schemas" "check-alive-timeout"; do
    if grep -Fq -- "$stale_text" "$OPTIMIZATIONS_SCRIPT"; then
        fail "Unexpected GNOME optimization remains in build/15-system-optimizations.sh: $stale_text"
    fi
done

for doc_file in "$README_EN" "$README_PT" "$BUILD_README"; do
    if grep -Fqi -- "dual desktop" "$doc_file"; then
        fail "Unexpected dual desktop wording in $doc_file"
    fi
    if grep -Fq -- "GNOME + COSMIC" "$doc_file"; then
        fail "Unexpected GNOME + COSMIC wording in $doc_file"
    fi
done

for stale_text in "Choosing Desktop at Login" "GDM session selector" "Desktop GNOME" "### GNOME desktop"; do
    if grep -Fq -- "$stale_text" "$README_EN"; then
        fail "Unexpected stale English README wording: $stale_text"
    fi
done

for stale_text in "Escolhendo o Desktop no Login" "Seletor de sessão no GDM" "Desktop GNOME"; do
    if grep -Fq -- "$stale_text" "$README_PT"; then
        fail "Unexpected stale Portuguese README wording: $stale_text"
    fi
done

printf 'PASS: test_cosmic_only_scripts.sh\n'
