# bluefin-cosmic-dx

This project was created using the finpilot template: <https://github.com/projectbluefin/finpilot>.

Portuguese version: [README.pt-BR.md](README.pt-BR.md)

It builds a custom bootc image based on Bluefin, using the multi-stage OCI pattern from the Bluefin ecosystem.

## What is this image

bluefin-cosmic-dx is a developer-focused Bluefin image with COSMIC as the desktop and a curated DX toolset.

## What changes in this version

Compared to Bluefin DX, this image adds:

- COSMIC desktop (System76) installed via COPR
- VSCode Insiders (default editor) installed via RPM
- Warp Terminal installed via RPM
- DX tooling baked into the image (containers, virtualization, build toolchain)

Base image: ghcr.io/ublue-os/base-main:latest

## Basic usage

Build locally:

1. Run the build:

   ```bash
   sudo just build
   ```

Create a VM image:

1. Build a QCOW2:

   ```bash
   sudo just build-qcow2
   ```

Switch your system to this image:

1. Rebase:

   ```bash
   sudo bootc switch ghcr.io/ericrocha97/bluefin-cosmic-dx:stable
   ```

2. Reboot:

   ```bash
   sudo systemctl reboot
   ```

Roll back to Bluefin DX:

1. Rebase back:

   ```bash
   sudo bootc switch ghcr.io/ublue-os/bluefin-dx:stable
   ```

2. Reboot:

   ```bash
   sudo systemctl reboot
   ```
