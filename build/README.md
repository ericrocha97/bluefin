# Build Scripts

This directory contains build scripts that run during image creation. Scripts are executed in numerical order by `10-build.sh`.

## How It Works

- The Containerfile runs only `10-build.sh`.
- `10-build.sh` then runs any scripts that match `/ctx/build/[1-9][0-9]*-*.sh` in ascending order (skipping itself).

## Included Scripts

- **`10-build.sh`** - Main build script. Copies Flatpak preinstall files, installs `copr-cli`, `earlyoom`, `ffmpegthumbnailer`, and `libvdpau-va-gl`, enables `podman.socket`, and runs the other numbered scripts.
- **`15-system-optimizations.sh`** - Installs CachyOS/LinuxToys system optimizations (sysctl, udev, modprobe, tmpfiles, journald), configures earlyoom, rpm-ostreed auto-updates, and GNOME tweaks.
- **`20-third-party-repos.sh`** - Installs VSCode Insiders and Warp Terminal from official RPM repos.
- **`30-cosmic-desktop.sh`** - Installs COSMIC desktop from System76's COPR repository.
- **`99-versions.sh`** - Writes a version manifest to `/usr/share/bluefin-cosmic-dx/manifest.json`.
- **`copr-helpers.sh`** - Helper functions for COPR management and logging.

## Custom Files (Brewfiles and ujust)

Custom Brewfiles (in `custom/brew/`) and ujust files (in `custom/ujust/`) are automatically copied during the build process if they exist.

## Creating Your Own Scripts

Create numbered scripts for different purposes:

```bash
# 20-drivers.sh - Hardware drivers
# 30-development.sh - Development tools
# 40-gaming.sh - Gaming software
# 50-cleanup.sh - Final cleanup tasks
```

### Script Template

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "Running custom setup..."
# Your commands here
```

### Best Practices

- Use descriptive names: `20-nvidia-drivers.sh` is better than `20-stuff.sh`
- One purpose per script: easier to debug and maintain
- Clean up after yourself: remove temporary files and disable temporary repos
- Test incrementally: add one script at a time and test builds

### Disabling Scripts

To temporarily disable a script without deleting it:

- Rename it with `.disabled` extension: `20-script.sh.disabled`
- Or remove execute permission: `chmod -x build/20-script.sh`

## Execution Order

The Containerfile runs:

```dockerfile
RUN /ctx/build/10-build.sh
```

Then `10-build.sh` runs any `15-*.sh`, `20-*.sh`, `30-*.sh`, etc. scripts in ascending order (skipping itself).

## Notes

- Scripts run as root during build
- Build context is available at `/ctx`
- Use `dnf5` for package management (not `dnf` or `yum`)
- Always use `-y` flag for non-interactive installs
