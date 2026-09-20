---
name: finpilot-ci
description: >-
  Jenkins production pipelines, GitHub Actions PR checks, Renovate
  configuration, and workflow pinning for bluefin-cosmic-dx. Use when changing
  .github/workflows/, .github/renovate.json5, or ci/jenkins/.
---

# bluefin-cosmic-dx CI

## When to Use

- Editing any `.github/workflows/*.yml`
- Editing `.github/renovate.json5` or `.github/workflows/renovate.yml`
- Working on `.github/workflows/build.yml` (PR check)
- Editing the Jenkins pipelines or scripts under `ci/jenkins/`
- Debugging CI failures or deciding what runs where

## When NOT to Use

- `Containerfile`, `Justfile`, or `build/*.sh` changes — use `finpilot-build`
- Runtime customizations (`custom/`) — use `finpilot-custom`
- Deciding where a package belongs — use `finpilot-packages`

## Core Process

1. **Identify the pipeline responsible** for your change (Workflow Map below)
2. **Confirm the file actually exists here** before referencing it
3. **Pin any new action or tool** to a commit SHA or explicit version with a
   Renovate tracking comment
4. **Validate textually**: `python3 -c "import yaml; yaml.safe_load(open('...'))"`
   for YAML, and `renovate-config-validator` when Renovate config changes
5. **Keep the two surfaces separate**: GitHub Actions is for PR checks;
   Jenkins is the production build/publish path

## Two CI Surfaces

This repository is a downstream custom image. It does **not** use the upstream
`projectbluefin/actions` composite workflows or a `stable` promotion branch.

| Surface | Role | Files |
| --- | --- | --- |
| GitHub Actions | PR checks and light validation; never publishes or signs images | `.github/workflows/build.yml`, `unit-tests.yml`, `validate-*.yml`, `renovate.yml`, `clean.yml` |
| Jenkins | Production build, GHCR publish, Cosign signing by digest, GitHub release, n8n notification | `ci/jenkins/Jenkinsfile.stable`, `ci/jenkins/Jenkinsfile.nvidia` |

## Workflow Map

| File | Trigger | Purpose |
| --- | --- | --- |
| `build.yml` | `pull_request` → `main` | Build the image as a PR check (`redhat-actions/buildah-build`); does **not** publish |
| `unit-tests.yml` | PR/push paths `build/**`, `custom/**`, `tests/**`, `Justfile` | BATS unit tests in `tests/unit/` |
| `validate-shellcheck.yml` | PR paths `build/**/*.sh` | `shellcheck -x` every build script |
| `validate-brewfiles.yml` | PR paths `custom/brew/**` | `bash build/validate-brewfiles.sh custom/brew` with Homebrew set up |
| `validate-flatpaks.yml` | PR paths `custom/flatpaks/**` | Verify Flatpak IDs against Flathub |
| `validate-justfiles.yml` | PR paths `custom/ujust/**`, `Justfile` | `just --unstable --fmt --check` |
| `validate-renovate.yml` | PR/push paths `.github/renovate.json5`, `.github/workflows/renovate.yml` | `renovate-config-validator --strict` |
| `validate-jenkins-tests.yml` | PR paths `ci/jenkins/**` | Run `bash ci/jenkins/tests/run-all.sh` |
| `renovate.yml` | Schedule every 6h, `workflow_dispatch`, config push | Self-hosted Renovate using `secrets.GITHUB_TOKEN` |
| `clean.yml` | Weekly schedule, `workflow_dispatch` | Delete GHCR images older than 90 days for `bluefin-cosmic-dx` |

There is no `pr-validation.yml`, `build-image.yml`,
`promote-main-to-stable.yml`, or `sync-stable-to-main.yml` here. Do not add
workflows that reference them.

## Jenkins Pipelines

Both pipelines build with `docker`, publish to GHCR, sign the published digest
with Cosign, create a GitHub release, and notify n8n from the `post` block.

| File | Schedule | Image | Notes |
| --- | --- | --- | --- |
| `ci/jenkins/Jenkinsfile.stable` | `H 2 * * 0` | `ghcr.io/ericrocha97/bluefin-cosmic-dx` | Default `BASE_IMAGE` (Bluefin DX) |
| `ci/jenkins/Jenkinsfile.nvidia` | `H 10 * * *` | `ghcr.io/ericrocha97/bluefin-cosmic-dx-nvidia` | Adds `--build-arg BASE_IMAGE=ghcr.io/ublue-os/bluefin-dx-nvidia-open:stable-daily`, release tag `v<date>-nvidia` |

- Both run on `DEFAULT_BRANCH = 'main'`; publish/sign/release stages are gated on
  `EFFECTIVE_BRANCH == DEFAULT_BRANCH`.
- Build context and metadata helpers live in `ci/jenkins/scripts/`
  (`generate_metadata.sh`, `extract_versions.sh`, `create_github_release.sh`,
  `sign_image.sh`, `notify_n8n.sh`). Shell tests live in `ci/jenkins/tests/`.
- The `Sign Image` stage reads the Jenkins credentials `cosign_key`
  (`Secret file`) and `cosign_pass` (`Secret text`) and calls
  `ci/jenkins/scripts/sign_image.sh` with `IMAGE_REPOSITORY@sha256:<digest>`;
  tags alone are never signed.
- Jenkins runs `bootc container lint --fatal-warnings` as part of the image
  build via the Containerfile; treat lint warnings as build failures.
- Full setup (credentials, plugins, n8n, PostgreSQL) is in
  `docs/jenkins/README.md`.

## Composite Action and Tool Pinning

Workflows here pin third-party actions to a commit SHA with a trailing
version comment, and Renovate updates the SHA:

```yaml
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v5
```

- Never use a floating tag (`@v1`, `@main`) for an action.
- Prefer pinned, well-known actions already used in this repo
  (`actions/checkout`, `ublue-os/container-storage-action`,
  `redhat-actions/*`, `Homebrew/actions/setup-homebrew`,
  `extractions/setup-just`, `renovatebot/github-action`,
  `dataaxiom/ghcr-cleanup-action`).
- Do not add `projectbluefin/actions` composite actions; they are not part of
  this repository's pipeline.

## Renovate Configuration

`renovate.json5` (JSON5, not JSON) uses `config:best-practices` plus:

- A custom regex manager that tracks images in the `Justfile` (`BIB_IMAGE`,
  `QEMU_IMAGE`) with tag and digest.
- Automerge for `pin`/`pinDigest` updates.
- Automerge for `dockerfile` digest updates that touch `Containerfile`.
- A disabled automerge rule for `ghcr.io/hhd-dev/rechunk`.
- GitHub Actions updates enabled for `.github/workflows/**.yml|yaml`.

The runner is `.github/workflows/renovate.yml`, scheduled every 6 hours, using
the built-in `secrets.GITHUB_TOKEN`. The `Justfile` and `Containerfile` are
tracked automatically; do not hand-edit a digest that Renovate manages.

## Signing

Cosign signing (traditional key) is enabled in the **Jenkins** production
pipelines. After `Push GHCR`, each pipeline captures the published digest and
signs `IMAGE_REPOSITORY@sha256:<digest>` in a `Sign Image` stage gated on
`main`, using the Jenkins credentials `cosign_key` (`Secret file`) and
`cosign_pass` (`Secret text`) through `ci/jenkins/scripts/sign_image.sh`.
`cosign.pub` is versioned for independent verification
(`cosign verify --key cosign.pub <image>@<digest>`). `build.yml` triggers on
pull requests only, so it never publishes or signs. Attestations, SBOM,
provenance and rechunking are separate concerns and stay out of scope. Do not
move signing or publishing to GitHub Actions.

## Common Rationalizations

| Rationalization | Reality |
| --- | --- |
| "I'll use `/releases/latest/` and pin it later." | You won't. Pin the version immediately; Renovate tracks the pin. |
| "Minor/patch automerge is fine." | This image ships to users' machines; keep automerge scoped to digest/pin. |
| "Every repository uses `projectbluefin/actions`." | This one does not. GitHub Actions is PR checks only; Jenkins publishes. |
| "`build.yml` publishes the image." | It triggers on `pull_request` to `main` only and does not push. Jenkins is production. |
| "I'll document the release as signed." | Accurate: Jenkins signs the published digest. Phrase it as Jenkins Cosign signing by digest, never as GitHub Actions or a tag signature. |
| "The upstream promotion workflow handles releases." | There is no promotion workflow; Jenkins builds from `main`. |

## Red Flags

- Referencing a workflow or branch that does not exist here
  (`pr-validation.yml`, `build-image.yml`, a `stable` branch, promotion)
- Using a floating action tag instead of a pinned SHA
- Installing a tool via `/releases/latest/` without a version pin
- Widening Renovate automerge to `minor`/`patch` for all packages
- Using `GITHUB_TOKEN` for a different repository (it cannot open PRs there)
- Claiming GitHub Actions signs or publishes releases, or documenting a tag
  signature instead of the digest signature
- Editing `ci/jenkins/Jenkinsfile.*` without running
  `bash ci/jenkins/tests/run-all.sh`

## Verification

- [ ] Did you confirm the workflow/Jenkinsfile exists before referencing it?
- [ ] Are new `uses:` entries pinned to a commit SHA with a version comment?
- [ ] Does the Renovate change keep automerge scoped to digest/pin?
- [ ] Does `renovate-config-validator --strict` pass when the config changes?
- [ ] Does `bash ci/jenkins/tests/run-all.sh` pass when `ci/jenkins/` changes?
- [ ] Were the changed YAML files parsed successfully with a YAML parser?
- [ ] Does the change describe Jenkins Cosign signing accurately (by digest, `cosign_key`/`cosign_pass`, `cosign.pub`) and keep GitHub Actions non-publishing?
- [ ] Does the light validation avoid a local image build?
