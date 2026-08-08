# vim: set ft=make :
################################
### custom-cosmic-theme.just
################################
## Apply Rosé Pine theme to COSMIC, Starship, Warp, Zen, and cursors

# Apply Rosé Pine theme to Starship prompt
[group('Theming')]
setup-rose-pine-starship:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "Setting up Rosé Pine for Starship..."
    mkdir -p "$HOME/.config"
    curl -fsSL --max-time 15 \
        -o "$HOME/.config/starship.toml" \
        "https://raw.githubusercontent.com/ericrocha97/starship/main/rose-pine.toml"
    echo "Done! Starship theme applied to ~/.config/starship.toml"
    echo "Restart your shell or run: source ~/.bashrc"

# Apply Rosé Pine theme to COSMIC Desktop and Terminal
[group('Theming')]
setup-rose-pine-cosmic:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "Setting up Rosé Pine for COSMIC Desktop and Terminal..."

    THEME_DIR="$HOME/.local/share/cosmic/themes"
    TERM_DIR="$HOME/.local/share/cosmic-term/color-schemes"
    TMPDIR=$(mktemp -d -t cosmic-theme.XXXXXXXXXX)
    trap 'rm -rf "$TMPDIR"' EXIT

    if ! git clone --depth 1 https://github.com/rose-pine/cosmic-desktop.git "$TMPDIR" 2>/dev/null; then
        echo "ERROR: Failed to clone rose-pine/cosmic-desktop. Check your network connection."
        exit 1
    fi

    mkdir -p "$THEME_DIR"
    if [[ -f "$THEME_DIR/RosePine.ron" ]]; then
        echo "COSMIC Desktop theme already installed at $THEME_DIR/RosePine.ron"
    else
        cp "$TMPDIR/themes/main/cosmic-settings.ron" "$THEME_DIR/RosePine.ron"
        echo "COSMIC Desktop theme installed to $THEME_DIR/RosePine.ron"
    fi

    mkdir -p "$TERM_DIR"
    if [[ -f "$TERM_DIR/RosePine.ron" ]]; then
        echo "COSMIC Terminal theme already installed at $TERM_DIR/RosePine.ron"
    else
        cp "$TMPDIR/themes/main/cosmic-term.ron" "$TERM_DIR/RosePine.ron"
        echo "COSMIC Terminal theme installed to $TERM_DIR/RosePine.ron"
    fi

    echo "Done! Open COSMIC Settings > Desktop > Appearance to select the theme."

# Apply Rosé Pine cursor theme
[group('Theming')]
setup-rose-pine-cursors:
    #!/usr/bin/env bash
    set -euo pipefail

    THEME="BreezeX-RosePine-Linux"
    SIZE="24"
    ICONS_DIR="$HOME/.local/share/icons"
    THEME_DIR="$ICONS_DIR/$THEME"

    echo "==> Installing ${THEME} cursor theme"

    if [[ ! -d "$THEME_DIR/cursors" ]]; then
        RELEASE_TAG=$(curl -fsSL --max-time 15 \
            https://api.github.com/repos/rose-pine/cursors/releases/latest \
            | grep -oP '"tag_name":\s*"\K[^"]+' || true)
        RELEASE_TAG="${RELEASE_TAG:-v1.0.2}"

        URL="https://github.com/rose-pine/cursors/releases/download/${RELEASE_TAG}/${THEME}.tar.xz"

        TMPDIR="$(mktemp -d)"
        TMPFILE="$TMPDIR/theme.tar.xz"
        trap 'rm -rf "$TMPDIR"' EXIT

        echo "Downloading ${URL}"
        curl -fL --max-time 60 "$URL" -o "$TMPFILE"

        echo "Extracting..."
        mkdir -p "$ICONS_DIR"
        tar -xf "$TMPFILE" -C "$ICONS_DIR"

        if [[ ! -d "$THEME_DIR/cursors" ]]; then
            FOUND="$(find "$ICONS_DIR" -type d -name "$THEME" | head -n1)"
            if [[ -n "$FOUND" && "$FOUND" != "$THEME_DIR" ]]; then
                rm -rf "$THEME_DIR"
                mv "$FOUND" "$THEME_DIR"
            fi
        fi

        if [[ ! -d "$THEME_DIR/cursors" ]]; then
            echo "ERROR: Cursor theme extraction failed."
            exit 1
        fi
        echo "Installed into $THEME_DIR"
    else
        echo "Theme already installed."
    fi

    echo ""
    echo "==> Configuring XCursor fallback"
    mkdir -p "$HOME/.icons/default"
    printf '%s\n' \
        '[Icon Theme]' \
        'Inherits=BreezeX-RosePine-Linux' \
        > "$HOME/.icons/default/index.theme"

    echo "==> Configuring GTK"
    mkdir -p "$HOME/.config/gtk-3.0"
    printf '%s\n' \
        '[Settings]' \
        "gtk-cursor-theme-name=$THEME" \
        "gtk-cursor-theme-size=$SIZE" \
        > "$HOME/.config/gtk-3.0/settings.ini"

    mkdir -p "$HOME/.config/gtk-4.0"
    printf '%s\n' \
        '[Settings]' \
        "gtk-cursor-theme-name=$THEME" \
        "gtk-cursor-theme-size=$SIZE" \
        > "$HOME/.config/gtk-4.0/settings.ini"

    echo "==> Configuring environment"
    PROFILE="$HOME/.profile"
    touch "$PROFILE"
    sed -i '/^export XCURSOR_THEME=/d' "$PROFILE"
    sed -i '/^export XCURSOR_SIZE=/d' "$PROFILE"
    printf '\n%s\n%s\n' \
        "export XCURSOR_THEME=$THEME" \
        "export XCURSOR_SIZE=$SIZE" \
        >> "$PROFILE"

    mkdir -p "$HOME/.config/environment.d"
    printf '%s\n' \
        "XCURSOR_THEME=$THEME" \
        "XCURSOR_SIZE=$SIZE" \
        > "$HOME/.config/environment.d/90-cursor.conf"

    echo "==> Applying via gsettings (if available)"
    if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface cursor-theme "$THEME" 2>/dev/null || true
        gsettings set org.gnome.desktop.interface cursor-size "$SIZE" 2>/dev/null || true
    fi

    echo ""
    echo "Done! Log out and back in for the cursor theme to take effect."
    echo "Theme: $THEME"
    echo "Size : ${SIZE}px"

# Apply Rosé Pine theme to Warp terminal
[group('Theming')]
setup-rose-pine-warp:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "Setting up Rosé Pine for Warp terminal..."

    WARP_THEMES_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/warp-terminal/themes"
    THEME_DIR="$WARP_THEMES_DIR/rose-pine-warp"

    if [[ -d "$THEME_DIR" ]]; then
        echo "Warp theme already cloned at $THEME_DIR"
        echo "To update: cd $THEME_DIR && git pull"
    else
        mkdir -p "$WARP_THEMES_DIR"
        if ! git clone --depth 1 https://github.com/sonngdev/rose-pine-warp.git "$THEME_DIR" 2>/dev/null; then
            echo "ERROR: Failed to clone sonngdev/rose-pine-warp. Check your network connection."
            rm -rf "$THEME_DIR"
            exit 1
        fi
        echo "Warp theme cloned to $THEME_DIR"
    fi

    echo ""
    echo "To activate: Open Warp > Settings > Appearance > Themes"
    echo "Scroll down to see Rosé Pine. You may need to restart Warp."

# Apply Rosé Pine theme to Zen Browser
[group('Theming')]
setup-rose-pine-zen:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "Setting up Rosé Pine for Zen Browser..."

    PROFILE_DIR=""

    find_zen_profile() {
        local root="$1"
        if [[ ! -d "$root" ]]; then
            return 1
        fi

        if [[ -f "$root/profiles.ini" ]]; then
            local path
            path=$(grep -oP 'Path=\K.*' "$root/profiles.ini" 2>/dev/null || true)
            if [[ -n "$path" ]]; then
                path=$(printf '%s\n' "$path" | head -1)
                if [[ -d "$root/$path" ]]; then
                    echo "$root/$path"
                    return 0
                fi
            fi
        fi

        local found=$(find "$root" -maxdepth 1 -type d \
            \( -name '*.default-release' -o -name '*.Default*' -o -name '*.default' \) 2>/dev/null \
            | head -1)
        if [[ -n "$found" ]]; then
            echo "$found"
            return 0
        fi

        return 1
    }

    PROFILE_DIR=$(find_zen_profile "$HOME/.zen" || \
                  find_zen_profile "$HOME/.var/app/app.zen_browser.zen/cache/zen" || \
                  find_zen_profile "$HOME/.var/app/app.zen_browser.zen/.zen" || \
                  echo "")

    if [[ -z "$PROFILE_DIR" || ! -d "$PROFILE_DIR" ]]; then
        echo "ERROR: Could not find Zen Browser profile directory."
        echo "Checked: ~/.zen ~/.var/app/app.zen_browser.zen/cache/zen"
        echo "Please open Zen Browser, then run this command again."
        exit 1
    fi

    echo "Found profile: $PROFILE_DIR"

    CHROME_DIR="$PROFILE_DIR/chrome"

    if [[ -f "$CHROME_DIR/userChrome.css" ]]; then
        echo "Zen Browser theme already installed at $CHROME_DIR"
    else
        TMPDIR=$(mktemp -d -t zen-theme.XXXXXXXXXX)
        trap 'rm -rf "$TMPDIR"' EXIT
        if ! git clone --depth 1 https://github.com/rose-pine/zen-browser.git "$TMPDIR" 2>/dev/null; then
            echo "ERROR: Failed to clone rose-pine/zen-browser. Check your network connection."
            exit 1
        fi

        mkdir -p "$CHROME_DIR"
        cp "$TMPDIR"/dist/* "$CHROME_DIR/"
        echo "Theme files copied to $CHROME_DIR"
    fi

    PREFS_FILE="$PROFILE_DIR/prefs.js"
    PREF_LINE='user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'
    if grep -qF "$PREF_LINE" "$PREFS_FILE" 2>/dev/null; then
        echo "Stylesheets preference already set."
    else
        echo "$PREF_LINE" >> "$PREFS_FILE"
        echo "Enabled legacy stylesheets preference."
    fi

    echo "Done! Restart Zen Browser for the theme to take effect."

# Configure Vicinae launcher for COSMIC (service, clipboard, shortcuts)
[group('Theming')]
setup-vicinae-cosmic:
    #!/usr/bin/env bash
    set -Eeuo pipefail

    echo "==> Configuring Vicinae for COSMIC..."

    echo ""
    echo "==> Enabling Vicinae user service"
    if ! systemctl --user is-enabled --quiet vicinae 2>/dev/null; then
        systemctl --user enable --now vicinae
        echo "Vicinae service enabled and started."
    else
        systemctl --user start vicinae 2>/dev/null || true
        echo "Vicinae service already enabled."
    fi

    echo ""
    echo "==> Enabling clipboard history"
    SYSTEM_DESKTOP="/usr/share/wayland-sessions/cosmic.desktop"
    USER_DESKTOP="$HOME/.local/share/wayland-sessions/cosmic.desktop"

    if grep -q "COSMIC_DATA_CONTROL_ENABLED=1" "$SYSTEM_DESKTOP" 2>/dev/null; then
        echo "Clipboard support already enabled in system image."
    elif [[ -f "$USER_DESKTOP" ]] && grep -q "COSMIC_DATA_CONTROL_ENABLED=1" "$USER_DESKTOP" 2>/dev/null; then
        echo "Clipboard support already enabled via user override."
    else
        echo "Creating user-level session override..."
        mkdir -p "$(dirname "$USER_DESKTOP")"
        sed 's#Exec=/usr/bin/start-cosmic#Exec=env COSMIC_DATA_CONTROL_ENABLED=1 /usr/bin/start-cosmic#' \
            "$SYSTEM_DESKTOP" > "$USER_DESKTOP"
        if grep -q "COSMIC_DATA_CONTROL_ENABLED=1" "$USER_DESKTOP"; then
            echo "Clipboard support enabled via $USER_DESKTOP"
        else
            echo "ERROR: Could not enable clipboard support."
            echo "Edit $USER_DESKTOP manually and add COSMIC_DATA_CONTROL_ENABLED=1 to the Exec line."
        fi
    fi

    echo ""
    echo "==> Installing COSMIC shortcuts"
    SHORTCUT_DIR="$HOME/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1"
    SHORTCUT_FILE="$SHORTCUT_DIR/custom"
    mkdir -p "$SHORTCUT_DIR"

    if grep -qF 'Spawn("vicinae toggle")' "$SHORTCUT_FILE" 2>/dev/null; then
        echo "Vicinae shortcuts already configured."
    elif [[ -f "$SHORTCUT_FILE" ]]; then
        echo "Shortcuts file already exists but does not contain Vicinae entries."
        echo "Add manually in COSMIC Settings > Keyboard > Shortcuts:"
        echo "  Super+Space  →  vicinae toggle"
        echo "  Super+V      →  vicinae vicinae://launch/clipboard/history"
    else
        printf '%s\n' \
            '{' \
            '    (' \
            '        modifiers: [' \
            '            Super,' \
            '        ],' \
            '        key: "space",' \
            '        description: Some("Toggle Vicinae"),' \
            '    ): Spawn("vicinae toggle"),' \
            '' \
            '    (' \
            '        modifiers: [' \
            '            Super,' \
            '        ],' \
            '        key: "v",' \
            '        description: Some("Clipboard History"),' \
            '    ): Spawn("vicinae vicinae://launch/clipboard/history"),' \
            '}' \
            > "$SHORTCUT_FILE"
        echo "Vicinae shortcuts installed."
    fi

    echo ""
    echo "Restart your COSMIC session to apply all changes."

# Apply all Rosé Pine themes and configure Vicinae
[group('Theming')]
setup-rose-pine-all: setup-rose-pine-cosmic setup-rose-pine-cursors setup-rose-pine-starship setup-rose-pine-warp setup-rose-pine-zen setup-vicinae-cosmic
    #!/usr/bin/env bash
    echo ""
    echo "================================="
    echo "  Rosé Pine setup complete!"
    echo "================================="
    echo ""
    echo "What to do next:"
    echo "  1. Open COSMIC Settings > Desktop > Appearance to select RoséPine"
    echo "  2. Open COSMIC Terminal > View > Color schemes to select RoséPine"
    echo "  3. Restart Warp > Settings > Appearance > Themes to select Rosé Pine"
    echo "  4. Restart Zen Browser for theme to take effect"
    echo "  5. Log out and back in for cursor and Vicinae changes"
    echo "  6. Restart your shell for Starship theme"

# Update all cloned theme repositories and Starship config
[group('Theming')]
update-rose-pine-all:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "==> Updating Rosé Pine themes..."

    echo ""
    echo "==> Updating Starship config"
    curl -fsSL --max-time 15 \
        -o "$HOME/.config/starship.toml" \
        "https://raw.githubusercontent.com/ericrocha97/starship/main/rose-pine.toml"
    echo "Starship theme updated."

    echo ""
    echo "==> Refreshing COSMIC theme..."
    TMPDIR=$(mktemp -d -t cosmic-update.XXXXXXXXXX)
    if git clone --depth 1 https://github.com/rose-pine/cosmic-desktop.git "$TMPDIR" 2>/dev/null; then
        mkdir -p "$HOME/.local/share/cosmic/themes"
        cp "$TMPDIR/themes/main/cosmic-settings.ron" "$HOME/.local/share/cosmic/themes/RosePine.ron"
        mkdir -p "$HOME/.local/share/cosmic-term/color-schemes"
        cp "$TMPDIR/themes/main/cosmic-term.ron" "$HOME/.local/share/cosmic-term/color-schemes/RosePine.ron"
        echo "COSMIC themes updated."
    else
        echo "WARNING: Failed to fetch COSMIC theme updates."
    fi
    rm -rf "$TMPDIR"

    echo ""
    echo "==> Updating Warp theme (git pull)"
    WARP_THEME_DIR="$HOME/.local/share/warp-terminal/themes/rose-pine-warp"
    if [[ -d "$WARP_THEME_DIR/.git" ]]; then
        git -C "$WARP_THEME_DIR" pull --ff-only 2>/dev/null && echo "Warp theme updated." || echo "Warp theme update skipped (network or merge conflict)."
    else
        echo "Warp theme not installed. Run setup-rose-pine-warp first."
    fi

    echo ""
    echo "==> Refreshing Zen Browser theme..."
    ZEN_TMPDIR=$(mktemp -d -t zen-update.XXXXXXXXXX)
    if git clone --depth 1 https://github.com/rose-pine/zen-browser.git "$ZEN_TMPDIR" 2>/dev/null; then
        find "$HOME"/.zen "$HOME"/.var/app/app.zen_browser.zen/cache/zen "$HOME"/.var/app/app.zen_browser.zen/.zen \
            -maxdepth 1 -type d \( -name '*.default-release' -o -name '*.Default*' -o -name '*.default' \) 2>/dev/null \
            | while IFS= read -r prof; do
                chrome_dir="$prof/chrome"
                if [[ -f "$chrome_dir/userChrome.css" ]]; then
                    mkdir -p "$chrome_dir"
                    cp "$ZEN_TMPDIR"/dist/* "$chrome_dir/"
                    echo "Updated: $chrome_dir"
                fi
            done || true
    else
        echo "WARNING: Failed to fetch Zen Browser theme updates."
    fi
    rm -rf "$ZEN_TMPDIR"

    echo ""
    echo "==> Update complete"

# Uninstall all Rosé Pine themes and Vicinae shortcuts
[group('Theming')]
uninstall-rose-pine-all:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "==> Uninstalling Rosé Pine themes..."
    echo "This will remove theme files. No system packages are affected."
    echo ""

    echo "Removing Starship theme..."
    rm -f "$HOME/.config/starship.toml"

    echo "Removing COSMIC themes..."
    rm -f "$HOME/.local/share/cosmic/themes/RosePine.ron"
    rm -f "$HOME/.local/share/cosmic-term/color-schemes/RosePine.ron"

    echo "Removing cursor theme..."
    rm -rf "$HOME/.local/share/icons/BreezeX-RosePine-Linux"
    rm -f "$HOME/.icons/default/index.theme"
    rm -f "$HOME/.config/gtk-3.0/settings.ini"
    rm -f "$HOME/.config/gtk-4.0/settings.ini"
    rm -f "$HOME/.config/environment.d/90-cursor.conf"
    if [[ -f "$HOME/.profile" ]]; then
        sed -i '/^export XCURSOR_THEME=/d' "$HOME/.profile"
        sed -i '/^export XCURSOR_SIZE=/d' "$HOME/.profile"
    fi

    echo "Removing Warp theme..."
    rm -rf "$HOME/.local/share/warp-terminal/themes/rose-pine-warp"

    echo "Removing Zen Browser theme..."
    find "$HOME"/.zen "$HOME"/.var/app/app.zen_browser.zen/cache/zen "$HOME"/.var/app/app.zen_browser.zen/.zen \
        -maxdepth 1 -type d \( -name '*.default-release' -o -name '*.Default*' -o -name '*.default' \) 2>/dev/null \
        | while IFS= read -r prof; do
            for css_file in userChrome.css userContent.css; do
                rm -f "$prof/chrome/$css_file"
            done
            rmdir "$prof/chrome" 2>/dev/null || true
            echo "Cleaned: $prof/chrome"
        done || true

    echo "Removing Vicinae COSMIC shortcuts..."
    rm -f "$HOME/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom"

    echo ""
    echo "==> Uninstall complete"
    echo "Log out and back in for all changes to take effect."
