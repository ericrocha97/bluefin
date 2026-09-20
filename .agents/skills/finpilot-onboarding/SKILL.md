---
name: finpilot-onboarding
description: >-
  Fork bootstrap playbook: rename the image identity (details in
  finpilot-templates), enable Actions, first green build, README "What Makes
  this Raptor Different" section, and branch protection. Use when creating a
  new fork from this template.
---

# bluefin-cosmic-dx Onboarding

## When to Use

- Creating a new fork from this template
- Bootstrapping a new bootc-based custom image repository
- Setting up GitHub Actions, Renovate, and branch protection for the first time
- Onboarding a new contributor who needs to understand the fork-to-first-build pipeline

## When NOT to Use

- The repository is already initialized and has had a successful build
- You are adding packages or changing build logic — use `finpilot-packages` or `finpilot-build`
- You are updating CI workflows — use `finpilot-ci`

This repository is already an initialized fork. Use this skill to bootstrap a
**new** fork, or as the reference playbook when re-initializing an identity.

## Core Process

1. **Fork the template**: Use "Use this template" on GitHub, or clone
   `projectbluefin/finpilot` and re-point the remote
2. **Rename the image identity** in every location (details and table:
   `finpilot-templates`)
3. **Enable GitHub Actions** in the new repository
4. **Configure Renovate auth**: the local workflow uses `secrets.GITHUB_TOKEN`;
   if you set a `RENOVATE_TOKEN`, update `.github/workflows/renovate.yml` to use it
5. **Configure branch protection** for `main`
6. **Trigger the first build** (GitHub Actions PR check; production is Jenkins)
7. **Add the "What Makes this Raptor Different" section to README** (template below)
8. **Confirm the signing state** — Jenkins signs published digests with Cosign

Keep day-one changes minimal and iterate in phases:

1. **Phase 1 — Bootstrap**: rename identity, enable Actions, trigger the first
   green PR check (this skill)
2. **Phase 2 — Customize**: add one or two packages, run the light validations
   (`finpilot-packages`, `finpilot-build`)
3. **Phase 3 — Runtime**: add Flatpak/Brew customizations, test in a VM when
   resources allow (`finpilot-custom`)
4. **Phase 4 — Production**: configure branch protection and the Jenkins
   pipelines (`finpilot-templates`, `finpilot-ci`)

Resist changing everything at once — each phase validates the previous.

Each step's completion criterion is the matching item in the Verification checklist below.

## Enable GitHub Actions

1. Go to the **Actions** tab in your new fork
2. Click **"I understand my workflows, go ahead and enable them"**
3. Verify that `.github/workflows/build.yml`, `unit-tests.yml`, and the
   `validate-*.yml` checks appear

In this repository, `build.yml` is a **PR check only**; it does not publish
images. Publication is handled by the Jenkins pipelines.

## Configure Renovate

1. The repository runs Renovate via `.github/workflows/renovate.yml` every 6
   hours using the built-in `secrets.GITHUB_TOKEN`.
2. To use a dedicated token instead, generate a **Classic Personal Access
   Token** with `repo` and `workflow` scopes, store it as `RENOVATE_TOKEN`, and
   change the workflow's `token:` input accordingly.
3. Validate the config textually: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/renovate.yml'))"` and review `.github/renovate.json5`.

## Branch Protection + Auto-Merge

### Enable Auto-Merge

1. **Settings → General → Pull Requests**
2. Check **"Allow auto-merge"**

### Configure Branch Protection for `main`

1. **Settings → Branches → Add rule**
2. Branch name pattern: `main`
3. Enable:
   - **Require a pull request before merging**
   - **Require status checks to pass before merging**
   - Add the PR checks that exist here (`Unit Tests`, the `validate-*` checks)
   - (Optional) **Require branches to be up to date before merging**

There is no `pr-validation.yml` or promotion workflow in this repository.
Production gating happens through Jenkins; branch protection here protects the
GitHub PR surface.

## First Green Build

After the rename and settings setup, trigger validation:

- **Option A**: Open a pull request to `main` and let the GitHub Actions checks
  run (`build.yml` PR check, `unit-tests.yml`, `validate-*.yml`)
- **Option B**: Trigger the relevant Jenkins pipeline (`ci/jenkins/Jenkinsfile.stable`
  or `ci/jenkins/Jenkinsfile.nvidia`), which builds, lints, and publishes

A successful build:

- Passes `bootc container lint --fatal-warnings`
- Publishes to GHCR via Jenkins:
  `ghcr.io/<owner>/bluefin-cosmic-dx:stable` and
  `ghcr.io/<owner>/bluefin-cosmic-dx-nvidia:stable`
- Appears under **Packages** in your repository

## README "What Makes this Raptor Different" Section

**CRITICAL**: Add this section near the top of `README.md` (after the title/intro, before detailed docs):

```markdown
## What Makes this Raptor Different?

Here are the changes from [Base Image Name]. This image is based on [Bluefin/Bazzite/Aurora/etc] and includes these customizations:

### Added Packages (Build-time)

- **System packages**: tmux, micro, mosh - [brief explanation of why]

### Added Applications (Runtime)

- **CLI Tools (Homebrew)**: neovim, helix - [brief explanation]
- **GUI Apps (Flatpak)**: Spotify, Thunderbird - [brief explanation]

### Removed/Disabled

- List anything removed from base image

### Configuration Changes

- Any systemd services enabled/disabled
- Desktop environment changes
- Other notable modifications

_Last updated: [date]_
```

**Maintenance requirement**: update this section on every package or
configuration change — see the update rules in `finpilot-maintain`.

## Signing

**Cosign signing (traditional key) is enabled in the Jenkins production
pipelines.** After `Push GHCR`, each pipeline signs the published digest
(`IMAGE_REPOSITORY@sha256:<digest>`) in a `Sign Image` stage gated on `main`,
using the Jenkins credentials `cosign_key` (`Secret file`) and `cosign_pass`
(`Secret text`) through `ci/jenkins/scripts/sign_image.sh`.

- Configure the two Jenkins credentials during onboarding; a first release build
  fails at `Sign Image` if they are missing.
- `cosign.pub` is versioned for verification:
  `cosign verify --key cosign.pub <image>@<digest>`.
- The build workflow (`.github/workflows/build.yml`) is PR-only and never
  publishes or signs; other GitHub Actions maintenance workflows (Renovate,
  cleanup) run on schedules.
- Never commit `cosign.key`; only `cosign.pub` may be committed.
- Attestations, SBOM, provenance and rechunking are separate concerns and stay
  out of scope.
- Keep `finpilot-templates`, `finpilot-maintain`, `finpilot-ci`, and this skill
  in sync when the signing setup changes.

## Common Rationalizations

| Rationalization                                                | Reality                                                                                                    |
| -------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| "I'll rename the obvious places and fix the rest later."       | Missing a rename location (Justfile, Jenkins env, `iso/*.toml`) causes silent failures months later. Do them all. |
| "I don't need branch protection for a personal fork."          | Without it, Renovate auto-merge won't work, and dependency PRs sit unmerged.                              |
| "I'll add the raptor section to README after I have packages." | Add the section immediately with placeholders. Update it iteratively.                                      |
| "Signing is too much work for a first build."                  | The Jenkins pipelines already sign; you only configure `cosign_key` and `cosign_pass`. Keep docs accurate. |
| "The upstream promotion workflow handles releases."            | This repo publishes with Jenkins and has no `promote-main-to-stable.yml`.                                  |

## Red Flags

- Fork repo still has the upstream template name in any identity location
- Documentation attributing signing to GitHub Actions or a tag instead of the Jenkins digest signature
- `cosign.key` added to the repo
- A documented release path references `projectbluefin/actions` or upstream
  workflows that do not exist here
- Branch protection enabled with required checks that do not exist in this repo
- README missing the "What Makes this Raptor Different" section entirely

## Verification

- [ ] All identity rename locations updated with the new image name?
- [ ] GitHub Actions enabled in the fork?
- [ ] Renovate auth configured and the workflow matches the chosen token?
- [ ] Auto-merge enabled in repository settings?
- [ ] Branch protection for `main` configured with checks that exist here?
- [ ] First build succeeded and the image published to GHCR via Jenkins?
- [ ] README contains the "What Makes this Raptor Different" section?
- [ ] Signing state documented accurately (Jenkins Cosign by digest; `cosign_key`/`cosign_pass`; `cosign.pub` for verification)?
