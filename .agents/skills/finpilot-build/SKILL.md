---
name: finpilot-build
description: >-
  Containerfile multi-stage build, the BASE_IMAGE build argument, Justfile
  local recipes, and build/*.sh script conventions for bluefin-cosmic-dx.
  Use when changing Containerfile, Justfile, or build/*.sh.
---

# bluefin-cosmic-dx Build System

## When to Use

- Editing `Containerfile` (ARGs, stages, base image, RUN directives)
- Editing `Justfile` (build recipes, VM/disk recipes, lint/format)
- Adding or modifying `build/*.sh` scripts
- Understanding how the NVIDIA variant differs from the standard build
- Debugging why a local build fails differently from Jenkins

## When NOT to Use

- CI workflow changes (`.github/workflows/`) or Jenkins edits
  (`ci/jenkins/`) — use `finpilot-ci`
- Runtime customizations (`custom/`) — use `finpilot-custom`
- Deciding where a package belongs — use `finpilot-packages`

## Core Process

1. **Identify which stage or ARG drives your change** in `Containerfile`
2. **Check the local base**: the image builds on **Bluefin DX**, selected by
   the global `ARG BASE_IMAGE=ghcr.io/ublue-os/bluefin-dx:stable`
3. **Edit the matching `build/*.sh` script** using the numbering convention
4. **Validate lightly** (shellcheck, `just check`, BATS) — a full image build
   is optional locally and is exercised by Jenkins
5. **Keep build-time content minimal**; push CLI/GUI tools to the runtime layer
   (`finpilot-packages`, `finpilot-custom`)

## Containerfile Layout

The `Containerfile` is a two-stage build following the Bluefin architecture
pattern:

```dockerfile
# Global ARG, declared before any FROM
ARG BASE_IMAGE=ghcr.io/ublue-os/bluefin-dx:stable

# Stage 1: ctx — combine local and imported OCI resources
FROM scratch AS ctx
COPY build /build
COPY custom /custom
COPY --from=ghcr.io/projectbluefin/common:latest /system_files /oci/common
COPY --from=ghcr.io/ublue-os/brew:latest /system_files /oci/brew

# Stage 2: final image
FROM ${BASE_IMAGE}
ARG BASE_IMAGE            # redeclared inside the stage so RUN can read it
ARG IMAGE_NAME="bluefin-cosmic-dx"
...
RUN /ctx/build/00-image-info.sh        # identity: image-info.json + os-release
RUN rm /opt && mkdir /opt              # immutable /opt for RPM installs
RUN /ctx/build/10-build.sh             # main script + numbered scripts
RUN /ctx/build/clean-stage.sh          # pre-lint cleanup
RUN bootc container lint --fatal-warnings
```

- `ARG BASE_IMAGE` is a **global** ARG (before `FROM`) and must be redeclared
  inside the final stage to be visible to `RUN`.
- The `ctx` stage exports local `build/`, `custom/`, and OCI resources under
  `/ctx/oci/common` and `/ctx/oci/brew`.
- `bootc container lint --fatal-warnings` is the final gate; it turns any
  warning into a build failure and runs in the image build and in Jenkins.

## Base Image and Variants

| Variant | How it is built | Base image |
| --- | --- | --- |
| Standard | `just build` / Jenkins `Jenkinsfile.stable` | `ghcr.io/ublue-os/bluefin-dx:stable` |
| NVIDIA | `just build-nvidia` / Jenkins `Jenkinsfile.nvidia` | `ghcr.io/ublue-os/bluefin-dx-nvidia-open:stable-daily` |

The NVIDIA variant is **the same Containerfile** built with a different
`BASE_IMAGE` value:

```bash
just build-nvidia   # adds --build-arg BASE_IMAGE=ghcr.io/ublue-os/bluefin-dx-nvidia-open:stable-daily
```

Production publication is handled by Jenkins:
`ci/jenkins/Jenkinsfile.stable` (standard) and `ci/jenkins/Jenkinsfile.nvidia`
(NVIDIA), both documented in `docs/jenkins/README.md`. Do **not** model the
NVIDIA variant by activating an extra build script; the `BASE_IMAGE` argument
and the NVIDIA pipeline are the local mechanism.

`build/00-image-info.sh` detects the variant from `BASE_IMAGE`: when the value
contains `nvidia`, it appends `-nvidia` to the image name and sets
`image-flavor` to `nvidia` in `/usr/share/ublue-os/image-info.json`.

## Build Script Conventions

### Numbering and Discovery

The Containerfile runs only `10-build.sh`. That script sources
`build/copr-helpers.sh` and then executes every script matching
`/ctx/build/[1-9][0-9]*-*.sh` in ascending order, skipping itself. There is no
Containerfile change needed to activate a numbered script.

| Script | Purpose |
| --- | --- |
| `00-image-info.sh` | Metadata only: `/usr/share/ublue-os/image-info.json` and `/usr/lib/os-release` |
| `10-build.sh` | Main script: copies `custom/`, installs base packages, runs numbered scripts |
| `15-system-optimizations.sh` | System tuning (sysctl, udev, journald, earlyoom, rpm-ostree auto-updates) |
| `20-*.sh` | Third-party repos and vendor packages (e.g. `20-third-party-repos.sh`) |
| `30-*.sh` | Desktop composition (e.g. `30-cosmic-desktop.sh`) |
| `40-*.sh` | Desktop removal / session switching (e.g. `40-remove-gnome.sh`) |
| `99-versions.sh` | Version manifest written into the image |
| `clean-stage.sh` | Always runs last: reverts `keepcache`, clears versionlock and `/var`, `/run`, `/tmp`, `/boot` |
| `copr-helpers.sh` | `copr_install_isolated` and logging helpers |
| `validate-brewfiles.sh` | Fail-closed Brewfile validator (no Ruby evaluation) |

### Script Rules

- Always use `dnf5` — never `dnf`, `yum`, or `rpm-ostree`
- Always use `dnf5 install -y` (non-interactive)
- COPR: use `source /ctx/build/copr-helpers.sh` then
  `copr_install_isolated "owner/repo" package...`; never leave a COPR enabled
- Third-party repos: create the repo file, install, then **remove the repo file**
  at the end of the script (see `build/20-third-party-repos.sh`)
- Start scripts with `#!/usr/bin/bash` or `#!/usr/bin/env bash` and
  `set -euo pipefail`
- `10-build.sh` uses `set -eoux pipefail`; keep new scripts consistent with
  their neighbors

### Tuning `package` lists

- Keep the base image lean: Bluefin DX already ships most developer tooling.
- Prefer runtime Brew/Flatpak for CLI and GUI tools (`finpilot-packages`).
- If a build-time install is optional or may be missing on a Fedora release,
  guard it and record a warning instead of failing the whole build (see the
  `libvdpau-va-gl` handling in `build/10-build.sh`).

## 00-image-info.sh Branding

The identity is data-driven, not hardcoded. `build/00-image-info.sh` reads
`IMAGE_NAME`, `IMAGE_VENDOR`, `UBLUE_IMAGE_TAG`, and `BASE_IMAGE_NAME` and
writes `image-info.json`. When documenting or extending it, keep the
`${IMAGE_NAME}`-style variables instead of a literal image name so the file
stays reusable across forks.

## Justfile Recipes

The `Justfile` is the local entry point. Useful groups:

| Group | Recipes |
| --- | --- |
| Build | `build`, `build-nvidia` |
| Build VM image | `build-qcow2`, `build-raw`, `build-iso`, `build-vhdx`, plus `rebuild-*` and `build-nvidia-*` variants |
| Run VM | `run-vm-qcow2`, `run-vm-raw`, `run-vm-iso`, `run-nvidia-vm-*`, `spawn-vm` |
| Just | `check`, `fix` |
| Utility | `clean`, `validate-brewfiles`, `lint`, `format` |

`just lint` requires `shellcheck` and runs it across all `*.sh` files.
`just format` requires `shfmt`. Neither recipe builds an image.

## Validation Without a Mandatory Full Build

This scope explicitly avoids heavy local builds. Use the light checks:

```bash
just check                                   # Justfile + *.just syntax
just lint                                    # shellcheck all *.sh
bash build/validate-brewfiles.sh custom/brew # Brewfile safety (requires brew)
bats tests/unit                              # BATS static unit tests
git diff --check                             # whitespace
```

The BATS suite (`tests/unit/`) includes
`containerfile-hardening_test.bats`, which reads the Containerfile only and
never starts a build.

A full image build (`just build`, `just build-nvidia`) or `bootc container
lint --fatal-warnings` is **optional locally** and is exercised by the Jenkins
pipelines. Do not make a local build a prerequisite for a documentation or
script-syntax change.

## Common Rationalizations

| Rationalization | Reality |
| --- | --- |
| "This repository pins every OCI `FROM` by digest, so I must add `@sha256:` everywhere." | The ctx stage currently uses `:latest` tags with a comment that Renovate can pin them to digests; do not invent pins. Update the tag or let Renovate act. |
| "I'll add an extra `RUN` line for my script." | Numbered scripts are discovered by `10-build.sh`; only `00-`, `10-`, `clean-stage.sh` and the final lint are explicit Containerfile steps. |
| "I'll model NVIDIA with an extra build script like upstream." | The NVIDIA variant is selected with `BASE_IMAGE` and `ci/jenkins/Jenkinsfile.nvidia`. No extra script is activated. |
| "I'll skip the full build and also delete the light checks." | `just check`, `just lint`, `bash build/validate-brewfiles.sh`, and `bats tests/unit` are cheap and expected. |
| "`dnf` is available, so use it." | Never. `dnf5` is the canonical tool in this repository. |

## Red Flags

- Using `dnf`, `yum`, or `rpm-ostree` in any build script
- A COPR left enabled after install (not using `copr_install_isolated`)
- A third-party repo file left in `/etc/yum.repos.d/` after install
- Editing `Containerfile` or a `build/*.sh` script without running shellcheck
- Adding a numbered script but not matching `/ctx/build/[1-9][0-9]*-*.sh`
- Claiming the image is signed, or adding signing steps to the build
- Making `just build` a required step for a change that only touches docs
- Hardcoding the image name where `${IMAGE_NAME}` is used

## Verification

- [ ] Does the change use `dnf5` (never `dnf`/`yum`/`rpm-ostree`)?
- [ ] Are COPRs isolated with `copr_install_isolated` and disabled afterwards?
- [ ] Are third-party repo files removed at the end of the script?
- [ ] Does a new script match `/ctx/build/[1-9][0-9]*-*.sh` and start with `set -euo pipefail`?
- [ ] Does `just check` pass?
- [ ] Does `just lint` pass (shellcheck)?
- [ ] Do `bats tests/unit` and `git diff --check` pass?
- [ ] Is `bootc container lint --fatal-warnings` still the final Containerfile step?
- [ ] Was the NVIDIA variant left on the `BASE_IMAGE` / Jenkins mechanism?
