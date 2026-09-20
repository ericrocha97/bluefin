---
name: finpilot-templates
description: >-
  Template identity rules for bluefin-cosmic-dx: the local rename locations,
  image identity ARGs, image-info.json, and AGENTS.md update rules. Jenkins
  signs published digests with Cosign. Use when renaming a fork or updating
  identity docs.
---

# bluefin-cosmic-dx Templates & Fork Setup

## When to Use

- Renaming the image identity in a fork (the local locations below)
- Checking that the identity ARGs and `image-info.json` agree
- Updating `AGENTS.md`, `README.md`, or setup documentation
- Documenting new mandatory setup steps for forks
- Explaining the signing state to a contributor

## When NOT to Use

- First-time fork bootstrap procedure — use `finpilot-onboarding`
- Build system changes — use `finpilot-build`
- CI workflow or Jenkins changes — use `finpilot-ci`
- Ongoing Renovate/README maintenance — use `finpilot-maintain`

## Core Process

1. **Rename every identity location** listed below
2. **Check the image identity ARGs** match the new name
3. **Confirm the signing state** — Jenkins signs published digests with Cosign
4. **Update `AGENTS.md`** per the rules below
5. **Verify** against the checklist at the end of this skill

This repository is a downstream custom image, not the upstream finpilot
template. The upstream "seven rename locations" table does not match this
repository; use the local list below instead.

## Local Identity Locations

When forking, change `bluefin-cosmic-dx` (and the `bluefin-cosmic-dx-nvidia`
variant) in these locations:

| # | File | What to change |
| --- | --- | --- |
| 1 | `Containerfile` | `# Name: bluefin-cosmic-dx` and the identity ARGs (`IMAGE_NAME`, `IMAGE_VENDOR`) |
| 2 | `Justfile` | `export image_name := env("IMAGE_NAME", "bluefin-cosmic-dx")` and `image_name_nvidia` |
| 3 | `README.md` | Title, GHCR badge URLs, and `bootc switch` examples |
| 4 | `README.pt-BR.md` | Same fields as `README.md`, in Portuguese |
| 5 | `artifacthub-repo.yml` | `repositoryID` and owner fields |
| 6 | `custom/ujust/README.md` | `localhost/bluefin-cosmic-dx:stable` in the bootc switch example |
| 7 | `.github/workflows/clean.yml` | `packages: bluefin-cosmic-dx` |
| 8 | `iso/iso.toml`, `iso/iso-nvidia.toml` | The bootc switch URL `ghcr.io/<owner>/bluefin-cosmic-dx:stable` |
| 9 | `AGENTS.md` | Identity references and the template rename list |

Missing an identity location causes the image to be published or cleaned up
under the wrong name. Nothing validates that all locations agree, so check them
together in one change.

## Image Identity ARGs

The `Containerfile` exposes identity ARGs for downstream branding:

```dockerfile
ARG IMAGE_NAME="bluefin-cosmic-dx"      # Image name
ARG IMAGE_VENDOR="ericrocha97"          # GitHub owner
ARG UBLUE_IMAGE_TAG="stable"            # Stream name
ARG BASE_IMAGE_NAME="bluefin-dx"        # Base image label
```

`build/00-image-info.sh` consumes them and generates
`/usr/share/ublue-os/image-info.json` (read by the ublue ecosystem). It reads
`VERSION_ID` from `/usr/lib/os-release` to populate `fedora-version`, but it does
**not** modify `/usr/lib/os-release`.

The script appends `-nvidia` to the image name when `BASE_IMAGE` contains
`nvidia`, so keep the `${IMAGE_NAME}`-style variables instead of hardcoding a
literal name. Do not re-introduce the upstream `FEDORA_MAJOR_VERSION` flow: this
repository follows the base image through `BASE_IMAGE` and Renovate.

## Signing (Jenkins Cosign)

Cosign signing (traditional key) is enabled in the **Jenkins** production
pipelines. Each pipeline signs the published digest
(`IMAGE_REPOSITORY@sha256:<digest>`) in a `Sign Image` stage gated on `main`,
using the Jenkins credentials `cosign_key` (`Secret file`) and `cosign_pass`
(`Secret text`) through `ci/jenkins/scripts/sign_image.sh`. `cosign.pub` is
versioned for verification (`cosign verify --key cosign.pub <image>@<digest>`).

- `build.yml` triggers on pull requests only, so it never publishes or signs.
- Never commit `cosign.key`; only `cosign.pub` may be committed.
- Attestations, SBOM, provenance and rechunking are separate concerns and stay
  out of scope; do not conflate them with the Cosign signature.
- Keep `finpilot-onboarding`, `finpilot-maintain`, `finpilot-ci`, and this skill
  in sync when the signing setup changes.

## AGENTS.md Update Rules

`AGENTS.md` is the Copilot/agent instructions file. When updating it:

- **Use semantic references** (`ARG IMAGE_NAME`, `FROM`, `build/10-build.sh`)
  instead of fragile line numbers where possible
- **Keep the skills entry point in sync.** `AGENTS.md` references
  `.agents/skills/` in its `## Agent Skills` section, which points at
  `.agents/skills/README.md` and the `finpilot-router` skill. Update those
  references when a skill is added, renamed or removed
- **Update the `Last Updated` date** on every substantive change
- **Do not add resolved items** (PR numbers, "done" notes) — those belong in git
  history
- **Keep the identity rename list in sync** with the table above when it changes

## Common Rationalizations

| Rationalization | Reality |
| --- | --- |
| "I only need to rename the obvious places." | Missing `clean.yml`, the ISO bootc URL, or the Justfile silently publishes or prunes the wrong package. Check every location. |
| "The upstream seven-location table is authoritative." | It is not. This fork has its own files (`README.pt-BR.md`, `iso/iso-nvidia.toml`). Use the local table. |
| "I'll update `AGENTS.md` later once the build works." | It drives agent behaviour on every subsequent session. Update it in the same change. |
| "I should add keyless signing like upstream." | This repo uses a traditional Cosign key inside Jenkins, not upstream keyless/OIDC. Document the real Jenkins flow instead. |

## Red Flags

- A fork still uses `bluefin-cosmic-dx` in `clean.yml` (cleanup targets the wrong package)
- A `cosign.pub` placeholder file or a committed `cosign.key`
- `AGENTS.md` referencing line numbers instead of semantic identifiers
- Documentation attributing signing to GitHub Actions or a tag instead of the Jenkins digest signature
- A rename that skips `iso/iso.toml`, `iso/iso-nvidia.toml`, or `README.pt-BR.md`
- The identity ARGs and `image-info.json` disagree with the bootc switch URL

## Verification

- [ ] Were all local identity locations updated?
- [ ] Do `IMAGE_NAME` / `IMAGE_VENDOR` ARGs match the fork?
- [ ] Does `build/00-image-info.sh` still derive the name from variables?
- [ ] Is the signing state documented accurately (Jenkins Cosign by digest, `cosign.pub` for verification)?
- [ ] Does `AGENTS.md` use semantic references and a current `Last Updated` date?
