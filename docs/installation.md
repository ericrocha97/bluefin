# Installing bluefin-cosmic-dx

This guide walks you through setting up bluefin-cosmic-dx from scratch: install the official Bluefin ISO, then rebase to this COSMIC-only image.

## Prerequisites

- A USB flash drive (8 GB minimum)
- A backup of any important data on the target machine
- A working internet connection

## 1. Download the Bluefin ISO

Go to the official installation page:

**[docs.projectbluefin.io/installation](https://docs.projectbluefin.io/installation/)**

Pick the ISO that matches your needs:

| ISO            | Best for                            |
| -------------- | ----------------------------------- |
| **Bluefin**    | General desktop use with GNOME      |
| **Bluefin DX** | Developers — includes extra tooling |

Either ISO works. The rebase step in section 4 will replace the desktop with COSMIC regardless of which you choose.

## 2. Write the ISO to a USB drive

Use **Fedora Media Writer** — a simple, reliable tool available for Linux, Windows, and macOS.

1. Download Fedora Media Writer from [fedoraproject.org](https://fedoraproject.org/workstation/download/) (scroll to the bottom for the standalone download)
2. Launch the tool and select **"Write custom image"** (or drag your downloaded `.iso` file onto the window)
3. Select your USB drive from the list
4. Click **"Write"** and wait for it to finish

> **Warning:** Everything on the USB drive will be erased.

## 3. Install Bluefin

1. Insert the USB drive into the target machine and boot from it (F2/F12/Del at startup to select boot device)
2. Select **"Install Bluefin"** from the boot menu
3. Follow the guided installer — choose your language, keyboard layout, disk, and user account
4. When the installer finishes, reboot and remove the USB drive

For a detailed walkthrough with screenshots, see the [official installation guide](https://docs.projectbluefin.io/installation/).

## 4. Rebase to bluefin-cosmic-dx

Log into your new Bluefin system and open a terminal. Run one of the following:

**Standard (Intel/AMD GPUs, VMs):**

```bash
sudo bootc switch ghcr.io/ericrocha97/bluefin-cosmic-dx:stable
```

**NVIDIA (RTX GPUs):**

```bash
sudo bootc switch ghcr.io/ericrocha97/bluefin-cosmic-dx-nvidia:stable
```

Then reboot:

```bash
sudo systemctl reboot
```

The system will now boot into COSMIC Greeter with the COSMIC desktop session.

## 5. After installation

Once logged in:

```bash
# Verify COSMIC is running
echo $XDG_CURRENT_DESKTOP   # should output "COSMIC"

# Install dev tool managers
ujust install-dev-managers

# Flatpak apps are installed automatically on first boot — check progress:
flatpak list
```

Available `ujust` commands:

```bash
ujust install-nvm        # Node.js version manager
ujust install-sdkman     # SDK manager (Java, Kotlin, Gradle, etc.)
ujust install-dev-managers  # Both of the above
ujust setup-vicinae-cosmic # Vicinae settings for COSMIC
```

## Next steps

- [README](../README.md) — project overview and build instructions
- [Official Bluefin docs](https://docs.projectbluefin.io/)
- [COSMIC desktop by System76](https://system76.com/cosmic/)
