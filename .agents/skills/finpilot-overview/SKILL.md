---
name: finpilot-overview
description: >-
  Architecture, repo layout, and build flow for the bluefin-cosmic-dx image.
  Use when orienting to the repository, understanding how the Containerfile
  and build scripts produce the image, or before picking a skill with
  finpilot-router.
---

# bluefin-cosmic-dx Overview

## When to Use

- Starting a new session in this repo
- Explaining how this image relates to Bluefin DX and the finpilot template
- Orienting before using `finpilot-router` to pick a skill
- Onboarding a new contributor or agent

## When NOT to Use

- You already know the area — use the relevant skill directly
- You need specific build or CI mechanics — use `finpilot-build` or `finpilot-ci`

## Core Process

1. **Read [`AGENTS.md`](../../../AGENTS.md)** for repository-wide rules and the skill sequence
2. **Identify your change area** (`Containerfile`/`Justfile` → build, workflows/Jenkins → ci, image identity → templates)
3. **Load the relevant skill** before touching anything
4. **Verify against the current repository patterns** before deviating from them

## Architecture

This is a **bootc image repository** following the Bluefin multi-stage build
architecture. It keeps the **Bluefin DX** base and ships **COSMIC** as the only
desktop session:

```
┌─────────────────────────────────────────────────────────────┐
│  Stage 1: ctx (FROM scratch)                                │
│    COPY build/  custom/                                     │
│    COPY --from=projectbluefin/common → /oci/common          │
│    COPY --from=ublue-os/brew         → /oci/brew            │
└─────────────────────────┬───────────────────────────────────┘
                          │ --mount=type=bind,from=ctx,source=/,target=/ctx
┌─────────────────────────▼───────────────────────────────────┐
│  Stage 2: Final image                                       │
│    FROM ${BASE_IMAGE}   (default ghcr.io/ublue-os/bluefin-dx:stable)
│    RUN build/00-image-info.sh   (image-info.json + os-release)
│    RUN rm /opt && mkdir /opt    (immutable /opt for RPM installs)
│    RUN build/10-build.sh        (runs 15-, 20-, 30-, 40-, 99- in order)
│    RUN build/clean-stage.sh     (pre-lint cleanup)
│    RUN bootc container lint --fatal-warnings
└─────────────────────────────────────────────────────────────┘
```

The **NVIDIA variant** is the same Containerfile built with a different
`BASE_IMAGE` (`ghcr.io/ublue-os/bluefin-dx-nvidia-open:stable-daily`), selected
by the existing `BASE_IMAGE` build argument and the Jenkins NVIDIA pipeline. Do
not activate an upstream `40-nvidia.sh.example`-style script to model it.

## Repo Layout

```
├── Containerfile          # Multi-stage build (ARG BASE_IMAGE, OCI context pins)
├── Justfile               # Local build automation (build, build-nvidia, VM/disk, lint)
├── build/                 # Build-time scripts (run in numerical order)
│   ├── 00-image-info.sh   # image-info.json + os-release branding
│   ├── 10-build.sh        # Main script; runs the numbered scripts
│   ├── 15-system-optimizations.sh
│   ├── 20-third-party-repos.sh
│   ├── 30-cosmic-desktop.sh
│   ├── 40-remove-gnome.sh
│   ├── 99-versions.sh
│   ├── clean-stage.sh     # Pre-lint artifact cleanup
│   ├── copr-helpers.sh    # copr_install_isolated helper
│   └── validate-brewfiles.sh
├── custom/                # Runtime: brew/, flatpaks/, ujust/, system-files/
├── ci/jenkins/            # Jenkinsfile.stable, Jenkinsfile.nvidia, scripts/, tests/
├── tests/unit/            # BATS unit tests (00-image-info, clean-stage, ...)
├── iso/                   # disk.toml, iso.toml, iso-nvidia.toml (local VM testing)
├── docs/                  # Installation, Jenkins, and design docs
├── .github/
│   ├── workflows/         # PR checks (build.yml, unit-tests.yml, validate-*.yml)
│   ├── renovate.json5     # Renovate config (OCI digests, GH Actions)
│   └── copilot-instructions.md
└── .agents/skills/        # Discoverable <skill-name>/SKILL.md directories
```

## Build and Publish Role

This repository is a **downstream custom image** forked from
[`projectbluefin/finpilot`](https://github.com/projectbluefin/finpilot); it is
not the upstream template and does not use `projectbluefin/actions` composite
workflows.

- **Production build/publish**: self-hosted Jenkins pipelines at
  `ci/jenkins/Jenkinsfile.stable` (standard) and `ci/jenkins/Jenkinsfile.nvidia`
  (NVIDIA). Operations are documented in `docs/jenkins/README.md`.
- **GitHub Actions**: `.github/workflows/build.yml` runs as a PR check only and
  does not publish images. `unit-tests.yml` and `validate-*.yml` run light
  validation.
- **Image metadata**: `build/00-image-info.sh` writes
  `/usr/share/ublue-os/image-info.json` and updates `/usr/lib/os-release`.
- **Signing**: Jenkins signs the published digest with a traditional Cosign key
  (credentials `cosign_key` and `cosign_pass`); `cosign.pub` is versioned for
  `cosign verify`. GitHub Actions never publishes or signs, and attestations,
  SBOM, provenance and rechunking stay out of scope.

## Scope Rules

To keep changes minimal and safe:

- **Doc tasks** (README, `docs/`, Agent Skills) → No CI impact, free to edit
- **CI tasks** (`.github/workflows/`, `.github/renovate.json5`, `ci/jenkins/`) → Trigger PR validation; Jenkins is the production pipeline
- **Build tasks** (`Containerfile`, `build/`, `Justfile`) → Validated by shellcheck and `bootc container lint --fatal-warnings`; a full local build (`just build`) is optional and must not be assumed
- **Runtime tasks** (`custom/`) → Trigger the matching `validate-*.yml` and BATS checks

### Files to AVOID Modifying

**Do NOT modify unless specifically asked:**

- `.github/renovate.json5` - Renovate configuration (auto-updates)
- `.github/workflows/validate-*.yml` - Validation workflows
- `.gitignore` - Prevents committing secrets
- `build/copr-helpers.sh` - Stable helper patterns
- `LICENSE` - Repository license
- `cosign.pub` - Public signing key

**Modify with extreme caution:**

- `.github/workflows/build.yml` - PR-check build workflow
- `ci/jenkins/Jenkinsfile.*` - Production pipelines
- `Justfile` - Users rely on these commands

## Common Rationalizations

| Rationalization                                      | Reality                                                             |
| ---------------------------------------------------- | ------------------------------------------------------------------- |
| "AGENTS.md has everything — no need to use skills." | AGENTS.md holds global rules. Skills provide task-specific instructions. |
| "It's just a custom image, not upstream infra."      | Jenkins publishes real images. Mistakes reach users.                |
| "The finpilot docs describe this repo."             | Upstream assumes `projectbluefin/actions` and keyless/OIDC signing. This repo uses Jenkins with a traditional Cosign key. Verify local facts first. |

## Red Flags

- Making `Containerfile` changes without using `finpilot-build`
- Adding a workflow that assumes `projectbluefin/actions` composite actions
- Updating pinned `@sha256:...` digests in `Containerfile` manually instead of letting Renovate do it
- Documenting signing as a GitHub Actions step, by tag only, or conflating it with attestations/SBOM/provenance/rechunking

## Verification

- [ ] Do I know which skill covers my change area?
- [ ] Have I loaded that skill?
- [ ] Does the change match the local Bluefin/Jenkins patterns rather than upstream finpilot?
