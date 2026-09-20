---
name: finpilot-maintain
description: >-
  Maintenance of an active bluefin-cosmic-dx fork: Renovate digest PRs, README
  raptor section updates, light validation loops, and maintenance schedules.
  Jenkins signs published digests with Cosign. Use when maintaining the fork
  after onboarding.
---

# bluefin-cosmic-dx Maintenance

## When to Use

- Reviewing and merging Renovate PRs for OCI digest and action bumps
- Updating the README "What Makes this Raptor Different?" section
- Running the light validation loop before opening a PR
- Planning a maintenance schedule for the fork
- Checking the runtime tool set (`rtk`, `topgrade`, `ujust install-default-apps`)

## When NOT to Use

- First-time fork setup — use `finpilot-onboarding`
- Adding new packages for the first time — use `finpilot-packages`
- Debugging a specific build failure — use `finpilot-troubleshooting`
- Renaming the image identity — use `finpilot-templates`

## Core Process

1. **Review incoming Renovate PRs** — merge when CI passes and the change is isolated
2. **Update the README raptor section** whenever packages or configuration change
3. **Run the light validation loop** before opening PRs (a full build is optional and CI/Jenkins owns it)
4. **Open PRs to `main`** — never push directly
5. **Keep the signing state accurate** — Jenkins signs published digests with Cosign

## Handle Renovate Digest PRs

Renovate opens PRs for:

- OCI image digest bumps in `Containerfile`
- GitHub Actions SHA updates in `.github/workflows/`
- Pinned tool versions in the `Justfile` (custom regex manager for `BIB_IMAGE`,
  `QEMU_IMAGE`) and other tracked references

The runner is `.github/workflows/renovate.yml`, scheduled every 6 hours using
the built-in `secrets.GITHUB_TOKEN`. Config lives in `.github/renovate.json5`
(JSON5, not JSON).

### Review Checklist

- [ ] CI passes (the `unit-tests.yml` and `validate-*.yml` checks; there is no `pr-validation.yml` here)
- [ ] The digest change is isolated to the expected file
- [ ] No unexpected version jumps (for example a base image change that also changes the desktop)
- [ ] Security advisories checked (Renovate usually flags CVEs in the PR body)

### Merge Strategy

Automerge is scoped to `pin`/`pinDigest` updates and Dockerfile digest updates
that touch `Containerfile`. Do not widen automerge to `minor`/`patch` for all
packages. Review non-digest changes manually before merging.

## Update README Raptor Section

The "What Makes this Raptor Different?" section in `README.md` must be updated
on every package or configuration change. The full section template is in
`finpilot-onboarding`.

| Change | Section to update |
| --- | --- |
| Added system package in `build/10-build.sh` | "Added Packages (Build-time)" |
| Added Brewfile package | "Added Applications (Runtime) → CLI Tools" |
| Added Flatpak | "Added Applications (Runtime) → GUI Apps" |
| Removed/disabled package or service | "Removed/Disabled" |
| Enabled/disabled systemd service | "Configuration Changes" |
| Desktop environment change | "Configuration Changes" |

### Format

```markdown
_Last updated: [date]_
```

Always update the date. Keep descriptions brief and user-focused, written for
typical Linux users, not developers.

### Runtime tool drift

`custom/brew/default.Brewfile` currently ships `rtk` and `topgrade`, and
`ujust install-default-apps` installs them. When the Brewfile changes, update
the README section, the `custom/brew/README.md` text, and the shortcut name if
needed. Validate Brewfiles with the safe validator, never `brew bundle check` on
an untrusted file:

```bash
just validate-brewfiles
# or
bash build/validate-brewfiles.sh custom/brew
```

## Signing (Jenkins Cosign)

Cosign signing (traditional key) is enabled in the **Jenkins** production
pipelines, and keeping it working is part of maintenance. After `Push GHCR`,
each pipeline captures the published digest and signs
`IMAGE_REPOSITORY@sha256:<digest>` in a `Sign Image` stage gated on `main`,
using the Jenkins credentials `cosign_key` (`Secret file`) and `cosign_pass`
(`Secret text`) through `ci/jenkins/scripts/sign_image.sh`.

- `build.yml` triggers on pull requests only, so it never publishes or signs.
- `cosign.pub` is versioned; verify a digest with
  `cosign verify --key cosign.pub <image>@<digest>`. If verification fails after
  a key rotation, confirm the versioned public key matches the private key in
  the `cosign_key` credential.
- Never commit `cosign.key`; only `cosign.pub` may be committed.
- Attestations, SBOM, provenance and rechunking are separate concerns and stay
  out of scope; do not conflate them with the Cosign signature.
- Keep `finpilot-templates`, `finpilot-onboarding`, `finpilot-ci`, and this
  skill in sync when the signing setup changes.

## Light Validation Loop

This scope avoids heavy local builds. Use the cheap checks that exist here:

```bash
just check                                   # Justfile + *.just syntax
just lint                                    # shellcheck all *.sh
bash build/validate-brewfiles.sh custom/brew # Brewfile safety (requires brew)
bats tests/unit                              # BATS static unit tests
git diff --check                             # whitespace errors
```

A full image build (`just build`, `just build-nvidia`) and
`bootc container lint --fatal-warnings` are optional locally and are exercised
by the Jenkins pipelines (`ci/jenkins/Jenkinsfile.stable`,
`ci/jenkins/Jenkinsfile.nvidia`). Do not make a local build a prerequisite for a
documentation or script-syntax change.

| Scenario | Light check |
| --- | --- |
| Changed a build script | `just lint`, `bats tests/unit` |
| Changed a ujust recipe | `just check` |
| Changed a Brewfile | `just validate-brewfiles` (safe validator) |
| Changed a Flatpak preinstall | Verify the app ID on Flathub; `validate-flatpaks.yml` in CI |
| Changed workflows/Renovate | Parse the YAML; `renovate-config-validator` when Renovate changes |
| Major base image change | Full loop when a VM is available; Jenkins covers production |

## PR vs Direct Push Policy

### Always open a PR to `main`

Direct pushes to `main` bypass validation and create untraceable changes. Use
Conventional Commits and the per-change checklists in `finpilot-pr-checklist`.

### Required checks

Branch protection should require checks that exist in this repository
(`BATS unit tests` and the `validate` checks from the `validate-*.yml` workflows).
Do not require a `pr-validation` check that does not exist here.

## Keeping OCI Digests Current via Renovate

Renovate handles digest updates automatically using `secrets.GITHUB_TOKEN`. If
Renovate stops creating PRs, see the Renovate section of
`finpilot-troubleshooting`; if a dedicated token is preferred, update
`.github/workflows/renovate.yml` accordingly (`finpilot-onboarding`).

## Maintenance Schedule Recommendations

### Weekly

- Review and merge Renovate PRs
- Confirm the `unit-tests.yml` and `validate-*.yml` checks pass on `main`

### Monthly

- Run the light validation loop
- Review and update the README raptor section if it drifted
- Check for security advisories on the base image (Renovate PRs or the GitHub Security tab)

### Quarterly

- Review and clean up old branches
- Review `build/*.sh` scripts for obsolete packages or patterns
- Re-check the identity locations and `image-info.json` for drift (`finpilot-templates`)

### Annually

- Review the base image stream (`BASE_IMAGE`) and OCI context tags
- Review documentation (`README.md`, `AGENTS.md`, skills) for accuracy
- Confirm the signing state is still documented accurately (Jenkins signs the published digest by digest)

## Common Rationalizations

| Rationalization | Reality |
| --- | --- |
| "I'll merge this Renovate PR without reading it — it is just a digest bump." | Always verify the affected file. A misconfigured rule could target the wrong image. |
| "I'll update the README later when I have more changes." | Update incrementally. Users rely on it for the current state. |
| "Local builds are optional since CI builds everything." | CI and Jenkins own the image build here. Use the light checks instead of a heavy local build. |
| "I'll push to main to save time." | PRs are cheap. Direct pushes bypass validation and branch protection. |
| "Maintenance should verify signing works." | Jenkins signs the published digest. Verify with `cosign verify --key cosign.pub <image>@<digest>`; if it fails after a key rotation, check `cosign.pub` against the `cosign_key` credential. |
| "The upstream promotion workflow handles releases." | There is no promotion workflow. Jenkins builds from `main`. |

## Red Flags

- Renovate PRs sitting unmerged for weeks
- README raptor section missing or severely outdated
- Direct pushes to `main` bypassing branch protection
- Documenting signing as a GitHub Actions step, by tag only, or conflating it with attestations/SBOM/provenance/rechunking
- A required branch-protection check that does not exist in this repository
- A Brewfile validated with `brew bundle check` instead of the safe validator
- Widening Renovate automerge beyond `pin`/`pinDigest` and Containerfile digests

## Verification

- [ ] Are all Renovate PRs merged or under active review?
- [ ] Is the README raptor section updated for the latest changes?
- [ ] Did the light validation loop pass (`just check`, `just lint`, `bash build/validate-brewfiles.sh custom/brew`, `bats tests/unit`, `git diff --check`)?
- [ ] Are all pushes to `main` via PR with checks that exist here?
- [ ] Is the signing state documented accurately (Jenkins Cosign by digest, `cosign.pub` for verification)?
- [ ] Is Renovate running with a valid token and current config?
