# bluefin-cosmic-dx

This project was created using the finpilot template: <https://github.com/projectbluefin/finpilot>.

Portuguese version: [README.pt-BR.md](README.pt-BR.md)

It builds a custom bootc image based on Bluefin DX, using the multi-stage OCI pattern from the Bluefin ecosystem.

## What Makes this Raptor Different?

Here are the changes from Bluefin DX. This image is based on Bluefin and includes these customizations:

### Added Packages (Build-time)

- **System packages**: Full COSMIC desktop environment including:
  - Core desktop stack: session, compositor, panel, launcher, applets, greeter
  - Native applications: Settings, Files (file manager), Edit (text editor), Terminal, Store (app store), Player (media player), Screenshot tool
  - System components: wallpapers, icons, notifications, OSD, app library, workspaces manager
  - Desktop portal integration (xdg-desktop-portal-cosmic)

### Added Applications (Runtime)

- **CLI Tools (Homebrew)**: None (no Homebrew additions yet).
- **GUI Apps (Flatpak)**: Zen Browser.

### Removed/Disabled

- None.

### Configuration Changes

- Dual desktop sessions available in GDM (GNOME and COSMIC).

*Last updated: 2026-02-03*

## What is this image

bluefin-cosmic-dx is a developer-focused Bluefin image with **GNOME + COSMIC dual desktop** support. You can choose which desktop environment to use at the login screen.

## What changes in this version

Based on **Bluefin DX**, this image adds:

- **COSMIC desktop** (System76) as an alternative to GNOME
- **VSCode Insiders** installed via RPM
- **Warp Terminal** installed via RPM
- **Dual desktop support**: Choose GNOME or COSMIC at login (GDM)
- All Bluefin DX features (containers, DevPods, CLI tools, etc.)

Base image: `ghcr.io/ublue-os/bluefin-dx:stable-daily`

## Basic usage

Build locally:

```bash
just build
```

Create a VM image:

```bash
just build-qcow2
```

Switch your system to this image:

```bash
sudo bootc switch ghcr.io/ericrocha97/bluefin-cosmic-dx:stable
sudo systemctl reboot
```

## Image signing (optional)

Image signing is disabled by default so first builds succeed immediately. Enable later for production use (see README section on signing in this repo).

Roll back to Bluefin DX:

```bash
sudo bootc switch ghcr.io/ublue-os/bluefin-dx:stable
sudo systemctl reboot
```

## Choosing Desktop at Login

At the GDM login screen, click the **⚙️ gear icon** to select:

- **GNOME** - Default Bluefin desktop
- **COSMIC** - System76's new desktop environment
