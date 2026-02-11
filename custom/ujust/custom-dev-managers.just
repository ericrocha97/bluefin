# vim: set ft=make :
################################
### custom-dev-managers.just
################################
## Install and configure NVM and SDKMAN

# Install NVM (Node Version Manager)
[group('Dev Managers')]
install-nvm:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "Installing NVM (Node Version Manager)"
    if [ -d "$HOME/.nvm" ]; then
        echo "NVM already installed at $HOME/.nvm"
    else
        mkdir -p "$HOME/.nvm"
        # Fetch latest release tag from GitHub API
        nvm_tag=$(curl -fsSL --max-time 15 https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep -oP '"tag_name":\s*"\K[^"]+' || echo "")
        if [ -z "$nvm_tag" ]; then
            nvm_tag="v0.40.4"
            echo "Failed to resolve latest NVM release tag. Falling back to ${nvm_tag}."
        fi
        curl -fsSL --max-time 30 "https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_tag}/install.sh" | bash
        echo "NVM installation complete."
    fi

    echo ""
    echo "Add to your shell config:"
    echo "  - Bash: ~/.bashrc"
    echo "  - Zsh: ~/.zshrc"
    echo "  - Fish: ~/.config/fish/config.fish (use a compatible nvm wrapper)"
    echo ""
    echo "For bash/zsh, add:"
    echo '  export NVM_DIR="$HOME/.nvm"'
    echo '  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"'
    echo '  [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"'
    echo ""
    echo "Reload: source ~/.bashrc or source ~/.zshrc"

# Install SDKMAN (SDK Manager)
[group('Dev Managers')]
install-sdkman:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "Installing SDKMAN (SDK Manager)"
    if [ -d "$HOME/.sdkman" ]; then
        echo "SDKMAN already installed at $HOME/.sdkman"
    else
        curl -fsSL --max-time 15 "https://get.sdkman.io" | bash
        echo "SDKMAN installation complete."
    fi

    echo ""
    echo "Add to your shell config:"
    echo "  - Bash: ~/.bashrc"
    echo "  - Zsh: ~/.zshrc"
    echo "  - Fish: ~/.config/fish/config.fish (SDKMAN does not support fish natively)"
    echo ""
    echo "For bash/zsh, add:"
    echo "  source \"$HOME/.sdkman/bin/sdkman-init.sh\""
    echo ""
    echo "Reload: source ~/.bashrc or source ~/.zshrc"

# Alias: install both NVM and SDKMAN
[group('Dev Managers')]
install-dev-managers: install-nvm install-sdkman
