---
name: finpilot-examples
description: >-
  Index of runnable build scripts and how numbered scripts are activated in
  bluefin-cosmic-dx. Covers the local discovery glob, worked examples, and how
  to add a new build script. Use when adding a build script or extending the
  build.
---

# bluefin-cosmic-dx Build Examples

## When to Use

- You need to add a third-party repository, vendor package, or desktop change
- You want a working starting point for a new `build/*.sh` script
- You need to understand how numbered build scripts are picked up
- You are documenting a new build pattern for contributors

## When NOT to Use

- You are editing an existing active `build/*.sh` script — edit it directly
- You are adding a simple package — use `build/10-build.sh` directly, no new
  script needed (`finpilot-packages`)
- You are changing CI or Jenkins — use `finpilot-ci`

## Core Process

1. **Find the closest existing script** in `build/` for your change type
2. **Create a new numbered `NN-name.sh`** that matches the discovery glob
3. **Follow the script rules** (`set -euo pipefail`, `dnf5`, isolated COPR)
4. **Validate lightly**: `shellcheck`, `just check`, `bats tests/unit`
5. **Open a PR**; CI and Jenkins exercise the real build

## How Scripts Are Discovered

Unlike the upstream finpilot template, this repository does **not** use an
`.example` → `.sh` rename plus an explicit Containerfile `RUN` block. There are
currently no `.example` scripts in `build/`.

Instead, the Containerfile runs only `build/10-build.sh`, and that script
executes every file matching:

```bash
/ctx/build/[1-9][0-9]*-*.sh
```

in ascending order, skipping itself. To activate a new build script you only
need to create it with a two-digit prefix and a `.sh` suffix. **No Containerfile
edit is required.**

| Prefix | Purpose | Example |
| --- | --- | --- |
| `15-` | System tuning and base configuration | `15-system-optimizations.sh` |
| `20-` | Third-party repos and vendor packages | `20-third-party-repos.sh` |
| `30-` | Desktop installation/composition | `30-cosmic-desktop.sh` |
| `40-` | Desktop removal / session switching | `40-remove-gnome.sh` |
| `99-` | Version manifest and final metadata | `99-versions.sh` |

`00-image-info.sh` and `clean-stage.sh` are explicit Containerfile steps, not
members of the discovery glob.

## Worked Examples

### `build/20-third-party-repos.sh` — vendor repos

**What it does:**

- Adds the Microsoft VS Code repo, imports the GPG key, installs
  `code-insiders`, then removes the repo file
- Adds the Warp Terminal repo, imports its key, installs `warp-terminal`, then
  removes the repo file
- Installs Vicinae from the official Terra release with a COPR fallback, then
  disables the fallback COPR
- Resolves the latest OpenLogi RPM via the GitHub API and installs it without
  scriptlets

**Use it when** a vendor only ships an RPM from its own repository. Copy the
enable → install → remove pattern for a new vendor.

**Expected validation:** shellcheck (`just lint`) and the CI PR check.

### `build/30-cosmic-desktop.sh` — COSMIC desktop

**What it does:**

- Installs the COSMIC package set with
  `copr_install_isolated "ryanabx/cosmic-epoch" ...`
- Verifies every package and the `cosmic.desktop` session file
- Enables `COSMIC_DATA_CONTROL_ENABLED=1` for Vicinae clipboard history

**Use it when** changing the desktop package set or desktop-level defaults.
GNOME removal and greeter activation live in `build/40-remove-gnome.sh`.

**Expected validation:** shellcheck and a careful desktop test when a VM is
available; the GitHub Actions PR check covers syntax, Jenkins covers the image.

### `build/15-system-optimizations.sh` and `build/99-versions.sh`

System tuning and version-manifest examples. Use `15-` for sysctl/udev/journald
style changes and `99-` for metadata written at the end of the build.

## Creating a New Build Script

1. **Name it** with the correct prefix and a descriptive suffix
   (`20-my-vendor.sh`, `30-my-desktop-tweak.sh`)
2. **Start from this template:**

```bash
#!/usr/bin/bash

set -eoux pipefail

# Source helper functions (includes logging utilities)
# shellcheck source=/dev/null
source /ctx/build/copr-helpers.sh

log_section "My build step"

echo "::group:: Install packages"
dnf5 install -y package-name
verify_package "package-name"
echo "::endgroup::"

log_success "My build step complete"
```

3. **Follow the conventions:**
   - `dnf5` only; `-y` for non-interactive installs
   - Isolated COPR via `copr_install_isolated`
   - Remove third-party repo files at the end
   - Verify installed packages with `verify_package`
4. **Document it** in `build/README.md` and, if reusable, add it to this skill

## Validation by Change Type

| Change | Light validation (local, cheap) | Full validation |
| --- | --- | --- |
| New vendor repo (`20-*.sh`) | `just lint`, `shellcheck build/20-*.sh` | Jenkins image build |
| Desktop change (`30-*.sh`, `40-*.sh`) | `just lint`, `bats tests/unit` | Jenkins build + VM test when available |
| System tuning (`15-*.sh`) | `just lint` | Jenkins image build |
| Metadata (`99-*.sh`) | `just lint`, `bats tests/unit` | Jenkins image build |

A full image build is **optional locally**; never make it a prerequisite for
reviewing a script. `bootc container lint --fatal-warnings` runs as the final
Containerfile step and in Jenkins.

## Common Rationalizations

| Rationalization | Reality |
| --- | --- |
| "I'll rename it like the upstream `.example` and add a RUN block." | This repository has no `.example` scripts and does not require a Containerfile edit. Create `NN-name.sh` and the discovery glob runs it. |
| "I'll name the script `my-thing.sh`." | The discovery glob requires a two-digit prefix (`[1-9][0-9]*-*.sh`); a script without it silently never runs. |
| "I'll leave it as a draft and check later." | Only files matching the glob run. Verify the name and run `shellcheck` before the PR. |
| "I'll build the whole image to test one script." | Jenkins covers the image. Locally use shellcheck and BATS; a full build is optional and resource-heavy. |

## Red Flags

- A new script whose name does not match `/ctx/build/[1-9][0-9]*-*.sh`
- New `.sh` file without `set -euo pipefail`
- Using `dnf` or `yum` instead of `dnf5`
- A COPR left enabled after install
- A third-party repo file not removed after install
- Missing shellcheck validation before opening a PR
- Duplicating build logic for the NVIDIA variant instead of using `BASE_IMAGE`

## Verification

- [ ] Does the new script match the `[1-9][0-9]*-*.sh` discovery glob?
- [ ] Does it start with `set -euo pipefail` and source `copr-helpers.sh`?
- [ ] Does it use `dnf5` and `verify_package`?
- [ ] Are COPRs isolated and third-party repo files removed?
- [ ] Does `just lint` (shellcheck) pass?
- [ ] Do `bats tests/unit` and `git diff --check` pass?
- [ ] Is the new script documented in `build/README.md`?
