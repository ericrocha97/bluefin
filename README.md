# bluefin-cosmic-dx

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/bluefin-cosmic-dx)](https://artifacthub.io/packages/search?repo=bluefin-cosmic-dx)
[![GHCR](https://img.shields.io/badge/GHCR-ghcr.io%2Fericrocha97%2Fbluefin--cosmic--dx-2ea44f?logo=github)](https://github.com/ericrocha97/bluefin/pkgs/container/bluefin-cosmic-dx)

This project was created using the finpilot template: <https://github.com/projectbluefin/finpilot>.

Portuguese version: [README.pt-BR.md](README.pt-BR.md)

It builds a COSMIC-only custom bootc image based on Bluefin DX, using the multi-stage OCI pattern from the Bluefin ecosystem.

## Build and Publish

- Official image build and publication runs via self-hosted Jenkins (`Jenkinsfile`).
- Published image registry: `ghcr.io/ericrocha97/bluefin-cosmic-dx`.
- GitHub Actions (`.github/workflows/build.yml`) now runs only as a PR check (`pull_request` for `main`) and does not publish images.

## What Makes this Raptor Different?

Here are the changes from Bluefin DX. This image is based on Bluefin and includes these customizations:

### Added Packages (Build-time)

- **System packages**: Full COSMIC desktop environment including:
  - Core desktop stack: session, compositor, panel, launcher, applets, greeter
  - Native applications: Settings, Files (file manager), Edit (text editor), Terminal, Store (app store), Player (media player), Screenshot tool
  - System components: wallpapers, icons, notifications, OSD, app library, workspaces manager
  - Desktop portal integration (xdg-desktop-portal-cosmic)
- **CLI Tools**: copr-cli (COPR repository management and monitoring)
- **System Tools**: earlyoom (OOM prevention), ffmpegthumbnailer (video thumbnails)
- **Codecs**: Full multimedia codecs via negativo17/fedora-multimedia (base image), libvdpau-va-gl
- **Third-party apps**: VSCode Insiders, Warp Terminal, Vicinae

### Added Applications (Runtime)

- **CLI Tools (Homebrew)**: None (no Brewfiles included yet).
- **GUI Apps (Flatpak)**: Zen Browser.

### Removed/Disabled

- **GNOME desktop session**: Removed so COSMIC is the only login session.
- **GDM**: Disabled/removed in favor of COSMIC Greeter.
- **GNOME-specific mutter tuning**: Removed because GNOME is no longer shipped as a desktop session.

### System Optimizations (CachyOS/LinuxToys)

- **sysctl**: CachyOS VM/network/kernel tweaks (swappiness, vfs_cache_pressure, dirty bytes, etc.)
- **udev rules**: IO schedulers (BFQ/mq-deadline/none), audio PM, SATA, HPET, CPU DMA latency
- **modprobe**: NVIDIA PAT + dynamic power management, AMD GPU options, module blacklist
- **tmpfiles**: Transparent Huge Pages (defer+madvise, shrinker at 80%)
- **journald**: Journal size limited to 50MB
- **earlyoom**: 5% memory/swap threshold, D-Bus notifications
- **Auto-updates**: rpm-ostreed AutomaticUpdatePolicy=stage
- **Fastfetch**: Custom config showing image name/version, COSMIC version, and build date (overrides upstream Bluefin config)

### Configuration Changes

- COSMIC Greeter is enabled as the default login manager.
- COSMIC is the only desktop session presented at login.
- Custom ujust commands available: install-nvm, install-sdkman, install-dev-managers.

*Last updated: 2026-04-24*

## What is this image

bluefin-cosmic-dx is a developer-focused Bluefin DX image that keeps the Bluefin DX base and ships COSMIC as the only desktop environment.

## What changes in this version

Based on **Bluefin DX**, this image adds and changes:

- **COSMIC desktop** (System76) as the only desktop session
- **COSMIC Greeter** as the login manager
- **GNOME desktop session removed** from the final image
- **VSCode Insiders** installed via RPM
- **Warp Terminal** installed via RPM
- **Vicinae** installed via Terra repo (Bazzite-compatible)
- All Bluefin DX development features that remain compatible with the COSMIC-only desktop target

Base image: `ghcr.io/ublue-os/bluefin-dx:stable-daily`

## Jenkins Pipeline Operations

For Jenkins CI/CD operations (GHCR publishing, GitHub release automation, n8n webhook ingestion, Postgres persistence, and email alerting), see `docs/jenkins/README.md` (PT-BR).

## Basic usage

### Just Commands

This project uses [Just](https://just.systems/) as a command runner. Here are the main commands available:

**Building:**

```bash
just build              # Build the container image
just build-vm           # Build VM image (QCOW2) - alias for build-qcow2
just build-qcow2        # Build QCOW2 VM image
just build-iso          # Build ISO installer image
just build-raw          # Build RAW disk image
```

**Running:**

```bash
just run-vm             # Run the VM - alias for run-vm-qcow2
just run-vm-qcow2       # Run VM from QCOW2 image
just run-vm-iso         # Run VM from ISO image
just run-vm-raw         # Run VM from RAW image
```

**Utilities:**

```bash
just clean              # Clean all temporary files and build artifacts
just lint               # Run shellcheck on all bash scripts
just format             # Format all bash scripts with shfmt
just --list             # Show all available commands
```

**Custom ujust commands (in the image):**

This image includes custom `ujust` commands for development managers:

```bash
ujust install-nvm
ujust install-sdkman
ujust install-dev-managers
```

There are no Brewfiles included by default. If you add `.Brewfile` files (matching the `*.Brewfile` pattern) anywhere in `custom/brew/`, they will be copied during build automatically.

**Complete workflow:**

```bash
# Build everything and run the VM
just build && just build-vm && just run-vm

# Or step by step:
just build              # 1. Build container image
just build-qcow2        # 2. Build VM image
just run-vm-qcow2       # 3. Run the VM
```

### Deploying to Your System

Switch your system to this image:

```bash
sudo bootc switch ghcr.io/ericrocha97/bluefin-cosmic-dx:stable
sudo systemctl reboot
```

Roll back to Bluefin DX:

```bash
sudo bootc switch ghcr.io/ublue-os/bluefin-dx:stable
sudo systemctl reboot
```

## Optional: Enable Image Signing

Image signing is optional. The repository keeps Cosign signing steps in `.github/workflows/build.yml` for future reuse, but this workflow currently runs only on PR checks and does not publish/sign release images.

- Generate keys with `cosign generate-key-pair`
- Add private key content as repository secret `SIGNING_SECRET`
- Keep `cosign.key` private (never commit); only `cosign.pub` may be committed

If you decide to re-enable GitHub Actions release builds later, these signing steps can be reactivated there. For the current production flow, Jenkins is responsible for build/publish.

## COSMIC Login

The image boots to COSMIC Greeter and starts the COSMIC Wayland session. GNOME is intentionally not offered as a login option.

## Troubleshooting

### COSMIC session does not appear

1. Verify packages: `rpm -qa | grep -i cosmic`
2. Check session file: `ls /usr/share/wayland-sessions/cosmic.desktop`
3. Check COSMIC Greeter: `systemctl status cosmic-greeter`

### VSCode or Warp fails to start

- Verify RPM install: `rpm -q code-insiders warp-terminal`
- Ensure /opt is writable inside the image (required for RPM installs)

### Local build fails

- Free disk space: `df -h`
- Clean and retry: `just clean && just build`
- Check logs: `journalctl -xe`

### VM does not boot

- Ensure KVM is available: `ls -l /dev/kvm`
- Rebuild VM image: `just build-qcow2`

## Screenshots

<details>
<summary>View screenshots</summary>

### COSMIC Greeter

![COSMIC Greeter](https://raw.githubusercontent.com/ericrocha97/bluefin/main/docs/images/cosmic-greeter.png)

### COSMIC desktop

![COSMIC desktop](https://raw.githubusercontent.com/ericrocha97/bluefin/main/docs/images/cosmic-desktop.png)

</details>
