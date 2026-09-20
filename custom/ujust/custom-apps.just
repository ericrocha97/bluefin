# vim: set ft=make :
################################
### custom-apps.just
################################
## Install default runtime applications delivered via Homebrew.

# Install the default Brewfile (rtk, topgrade)
[group('Apps')]
install-default-apps:
    #!/usr/bin/env bash
    set -euo pipefail
    brew bundle --file /usr/share/ublue-os/homebrew/default.Brewfile
