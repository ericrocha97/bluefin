# System Configuration Files

This directory contains system-level configuration files that are copied into the image during build by the `15-system-optimizations.sh` script.

## Origin

These files are extracted from the [LinuxToys](https://github.com/psygreg/linuxtoys) project's `optimize-cfg-ublue` RPM package, which ports [CachyOS](https://github.com/CachyOS/CachyOS-Settings) system optimizations to Atomic Fedora (Universal Blue).

Instead of installing the RPM as a layered package at runtime, we bake these configs directly into the image at build time.

## File Inventory

### sysctl — Kernel & VM Tuning

| File | Description |
|------|-------------|
| `usr/lib/sysctl.d/99-cachyos-settings.conf` | CachyOS VM tweaks (swappiness=100, vfs_cache_pressure=50, dirty bytes), kernel settings (NMI watchdog off, kptr_restrict), and network tuning |
| `etc/sysctl.d/99-splitlock.conf` | Disables split lock mitigation for better performance |

### udev rules — Hardware Optimization

| File | Description |
|------|-------------|
| `usr/lib/udev/rules.d/60-ioschedulers.rules` | Auto-selects IO scheduler: BFQ for HDD, mq-deadline for SSD, none for NVMe |
| `usr/lib/udev/rules.d/20-audio-pm.rules` | Audio device power management |
| `usr/lib/udev/rules.d/50-sata.rules` | SATA link power management |
| `usr/lib/udev/rules.d/40-hpet-permissions.rules` | HPET device permissions for low-latency apps |
| `usr/lib/udev/rules.d/69-hdparm.rules` | Hard drive parameter configuration |
| `usr/lib/udev/rules.d/99-cpu-dma-latency.rules` | CPU DMA latency tuning |

### modprobe — GPU Driver Options

| File | Description |
|------|-------------|
| `usr/lib/modprobe.d/nvidia.conf` | NVIDIA: PAT enabled, dynamic power management for Turing+ mobile GPUs |
| `usr/lib/modprobe.d/amdgpu.conf` | AMD GPU driver options |
| `usr/lib/modprobe.d/blacklist.conf` | Blacklist for unnecessary kernel modules |

### tmpfiles — Transparent Huge Pages

| File | Description |
|------|-------------|
| `usr/lib/tmpfiles.d/thp.conf` | THP defrag set to `defer+madvise` (improves tcmalloc performance) |
| `usr/lib/tmpfiles.d/thp-shrinker.conf` | THP shrinker threshold at 80% (reduces memory waste from THP=always) |

### systemd — Service Configuration

| File | Description |
|------|-------------|
| `usr/lib/systemd/journald.conf.d/00-journal-size.conf` | Limits journal size to 50MB |

### Custom Configs

| File | Description |
|------|-------------|
| `etc/default/earlyoom` | earlyoom: 5% memory/swap threshold, D-Bus notifications, protects desktop processes |
| `etc/rpm-ostreed.conf.d/10-auto-updates.conf` | Enables automatic update staging (applied on reboot) |
| `usr/share/glib-2.0/schemas/99-custom.gschema.override` | GNOME mutter check-alive-timeout = 20s |

## References

- [LinuxToys](https://github.com/psygreg/linuxtoys) — Source of the ported configs
- [CachyOS Settings](https://github.com/CachyOS/CachyOS-Settings) — Original upstream configs
- [optimize-cfg-ublue spec](https://github.com/psygreg/linuxtoys/blob/master/resources/optimize-cfg-ublue/rpmbuild/SPECS/optimize-cfg-ublue.spec) — RPM spec file
