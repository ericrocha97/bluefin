# ISO and VM Build Guide

This directory contains configuration files for local testing only.

## Files

- disk.toml: Disk image configuration used for QCOW2 and RAW builds
- iso.toml: ISO installer configuration (Anaconda + kickstart)

## Common Commands

Build a container image first:

```bash
just build
```

Build a QCOW2 VM image:

```bash
just build-qcow2
just run-vm-qcow2
```

Default local VM login credentials for QCOW2/RAW test images:

- Username: `user`
- Password: `user`

Change the user password hash in `iso/disk.toml` before distributing artifacts.

Build a RAW VM image:

```bash
just build-raw
just run-vm-raw
```

Build an ISO installer:

```bash
just build-iso
just run-vm-iso
```

## Important

Update the bootc switch URL in iso.toml before distributing the ISO:

```toml
bootc switch --mutate-in-place --transport registry ghcr.io/USERNAME/REPO:stable
```

## Uploading ISOs (Optional)

The rclone/ folder includes example configs for common providers.
