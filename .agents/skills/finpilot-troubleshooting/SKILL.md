---
name: finpilot-troubleshooting
description: >-
  Consolidated symptom → cause → fix tables for bluefin-cosmic-dx. Covers build
  and strict-lint failures, Jenkins and GitHub Actions CI failures, runtime
  issues, Renovate, COPR persistence, and ujust command-not-found. Use when
  something is broken and you need a quick diagnosis.
---

# bluefin-cosmic-dx Troubleshooting

## When to Use

- An image build or `bootc container lint --fatal-warnings` fails
- Jenkins or a GitHub Actions PR check is failing and the error is unclear
- A runtime issue appears after deployment (missing packages, failed services)
- Renovate is not creating PRs or is failing validation
- A COPR repository seems to persist across builds
- A `ujust` command is not found or not working

## When NOT to Use

- You are still setting up the fork for the first time — use `finpilot-onboarding`
- You are deciding where to add a package — use `finpilot-packages`
- You are planning ongoing maintenance — use `finpilot-maintain`
- You need the build/CI mechanics themselves — use `finpilot-build` or `finpilot-ci`

## Core Process

1. **Identify the symptom** in the tables below
2. **Check the likely cause** against the real repository files
3. **Apply the lightest correct fix**
4. **Verify with a cheap check first** (see below); the full image build is
   reproduced by CI/Jenkins, not required for every fix

This scope avoids heavy local image builds. Prefer the light checks that exist
here and let GitHub Actions/Jenkins reproduce the image build:

```bash
just check                                   # Justfile + *.just syntax
just lint                                    # shellcheck across *.sh
bats tests/unit                              # static BATS tests (no build)
bash build/validate-brewfiles.sh custom/brew # safe Brewfile validator
bash ci/jenkins/tests/run-all.sh             # Jenkins shell tests
git diff --check                             # whitespace
```

A full image build and its final `bootc container lint --fatal-warnings` gate
are owned by `.github/workflows/build.yml` (PR check) and the Jenkins pipelines.
Only run a full build on a machine that can afford it, and never make it a
prerequisite for a documentation or script-syntax fix.

## Build and Strict-Lint Failures

| Symptom | Cause | Solution |
| --- | --- | --- |
| Image build fails: "permission denied" | Build context file ownership or modes, or a missing permission in the build environment | Check ownership/modes under `build/` and `custom/`; signing is disabled here, so this is not a signing-key problem |
| Image build fails: "package not found" | Typo, or package unavailable in the configured repos | Check spelling, verify on RPMfusion, add a COPR only through `copr_install_isolated` (see `finpilot-packages`) |
| Image build fails: "base image not found" / "manifest unknown" | Invalid `ARG BASE_IMAGE` tag or digest | Verify the default in `Containerfile` and the `--build-arg` in `ci/jenkins/Jenkinsfile.*`; let Renovate manage digests |
| `bootc container lint --fatal-warnings` fails | Leftover artifacts, invalid image structure, or an unclean `/var`, `/run`, `/tmp`, `/boot` | `build/clean-stage.sh` runs last and must clean these; keep the lint step fatal and inspect its exact warning |
| shellcheck error | Syntax or unsafe pattern in a `build/*.sh` script | `just lint`, or `shellcheck -x build/<script>.sh`, then fix every error |
| Multi-stage build fails at the `ctx` stage | Missing `COPY --from=` or an invalid OCI image reference | Verify the OCI sources and paths in the `Containerfile` `ctx` stage |
| A numbered script does not run | The filename does not match the discovery glob | Rename it to `/ctx/build/[1-9][0-9]*-*.sh` (for example `20-*.sh`); `10-build.sh` runs them in order |
| NVIDIA variant fails: driver or akmods error | Wrong `BASE_IMAGE` for the variant, or a kernel/flavor mismatch | Confirm `ci/jenkins/Jenkinsfile.nvidia` passes `ghcr.io/ublue-os/bluefin-dx-nvidia-open:stable-daily` as `BASE_IMAGE`; the NVIDIA variant is selected by `BASE_IMAGE`, never by activating an extra upstream script |
| Third-party package disappears or the repo leaks | The vendor repo file was left in place | Remove the repo file at the end of the script (see `build/20-third-party-repos.sh`) |

## CI Failures

There are two CI surfaces: GitHub Actions for PR checks and light validation,
and Jenkins for production build/publish. There is no `pr-validation.yml` or
`build-image.yml` here.

| Symptom | Cause | Solution |
| --- | --- | --- |
| `build.yml` (PR check) image build fails | Same causes as a build failure above | Reproduce with the light checks; inspect the failing build step, not a local full build |
| `unit-tests.yml` — BATS unit tests fail | A `tests/unit/*.bats` assertion failed | Run `bats tests/unit` locally; these tests read files and never start an image build |
| `validate-shellcheck.yml` fails | Syntax/unsafe pattern in `build/**/*.sh` | Run `just lint` (or `shellcheck -x`) and fix every error |
| `validate-brewfiles.yml` fails | Interpolated names, trailing arguments, or non-literal taps in a Brewfile | Run `bash build/validate-brewfiles.sh custom/brew`; never validate by evaluating Ruby |
| `validate-flatpaks.yml` fails | App ID does not exist on Flathub, or the INI entry is malformed | Verify the ID on Flathub and use `[Flatpak Preinstall <id>]` with `Branch=stable` |
| `validate-justfiles.yml` fails | `.just` or `Justfile` formatting/syntax error | Run `just check` and fix formatting |
| `validate-renovate.yml` fails | Invalid `.github/renovate.json5` | Run `renovate-config-validator --strict` |
| `validate-jenkins-tests.yml` fails | A `ci/jenkins/tests/` shell test broke | Run `bash ci/jenkins/tests/run-all.sh` |
| Jenkins fails at lint | A strict `bootc container lint --fatal-warnings` warning | Fix the artifact or image-structure warning; warnings are build failures |
| Jenkins build succeeds but the image is not published | Publish/release stages are gated on the default branch | Confirm `EFFECTIVE_BRANCH == DEFAULT_BRANCH` (`main`) and that registry credentials are present |
| A check reports "signed" or expects a signature | Signing is disabled in this scope | Do not add signing steps; treat cosign verification as out of scope |

## Runtime Issues

| Symptom | Cause | Solution |
| --- | --- | --- |
| Flatpaks not installed | Expected — they install after first boot | Ensure network access on first boot, or run `ujust install-default-apps` |
| Brew missing or not found | Homebrew not extracted yet, or `brew-setup.service` failed | Check `systemctl status brew-setup.service`; Homebrew is provisioned on first boot, not user-installed |
| `bootc switch` fails | Wrong image URL or missing registry credentials | Verify the switch URL matches the repo (see `iso/iso.toml`) and that the image is published |
| `bootc switch` fails: "image not found" | Image not yet published | Trigger the Jenkins standard or NVIDIA pipeline and confirm the package exists in GHCR |
| Service not starting | Service not enabled, or a missing dependency | `systemctl status <service>`; enable it in `build/10-build.sh` |
| Missing package after boot | Build-time vs runtime confusion | Build-time packages belong in `build/*.sh` via `dnf5`; CLI/GUI tools belong in `custom/` (see `finpilot-packages`) |
| `/opt` is not writable | `/opt` is made immutable on purpose | RPM installs that write to `/opt` need the `RUN rm /opt && mkdir /opt` step already present in the `Containerfile` |

## Renovate Issues

| Symptom | Cause | Solution |
| --- | --- | --- |
| Renovate not creating PRs | Token invalid/expired, or the schedule has not run | The runner uses `secrets.GITHUB_TOKEN` and runs every 6 hours; check `.github/workflows/renovate.yml` logs |
| Renovate PR fails `validate-renovate.yml` | Invalid `renovate.json5` | Run `renovate-config-validator --strict` and fix the config |
| Renovate updates the wrong file | Over-broad rule or regex manager | Narrow `matchPackageNames`/`matchPaths`; the `Justfile` `BIB_IMAGE`/`QEMU_IMAGE` rules are intentional |
| Renovate automerges too much | Automerge widened beyond digest/pin | Keep automerge scoped to `pin`/`pinDigest` and `Containerfile` digests; see `finpilot-ci` |

## COPR Persistence Issues

| Symptom | Cause | Solution |
| --- | --- | --- |
| COPR packages missing after boot | The COPR was not isolated/disabled correctly | Use `copr_install_isolated` from `build/copr-helpers.sh`: enable → install → disable |
| COPR conflicts on update | Multiple COPRs left enabled | Disable every COPR after install; never leave one active in the image |
| `dnf5 copr list` shows unexpected repos | A stale repo file remains | Remove the leftover file from `/etc/yum.repos.d/`; prefer `copr_install_isolated` over manual repo files |

## ujust Command Not Found

| Symptom | Cause | Solution |
| --- | --- | --- |
| `ujust` not found | Shell PATH not reloaded | Open a new terminal or re-source the shell profile |
| `ujust --list` is missing custom commands | `.just` files were not consolidated during the build | Verify the files exist in `custom/ujust/` and that `build/10-build.sh` copies them into `/usr/share/ublue-os/just/60-custom.just` |
| `ujust <command>` fails | Syntax error inside the recipe | Run `just --unstable --fmt --check -f custom/ujust/<file>.just` (or `just check`) |
| `ujust install-default-apps` fails | Brew not installed, or the Brewfile path is wrong | Verify `brew` and `/usr/share/ublue-os/homebrew/default.Brewfile`; the recipe must contain no system package manager |
| A recipe is rejected for installing a system package | ujust is user-level only | Move the install to a `build/*.sh` script; never use `dnf5`, `dnf`, `yum`, or `rpm-ostree` in ujust |

## Common Rationalizations

| Rationalization | Reality |
| --- | --- |
| "It works on my machine, so CI must be broken." | CI/Jenkins is the reproducible source of truth. Reproduce with the light checks and the failing step's log. |
| "I should run a full image build to debug every fix." | A full build is heavy and owned by CI/Jenkins. Use `just lint`, `bats tests/unit`, and the change-type validator first. |
| "Renovate is broken — it hasn't opened a PR in days." | Renovate runs every 6 hours on a schedule. Check the workflow logs before assuming failure. |
| "I can skip shellcheck because CI will catch it." | `just lint` takes seconds and keeps the PR queue clean; it is a hard gate in `validate-shellcheck.yml`. |
| "The COPR is disabled, so the repo file cannot be the problem." | Repo files can persist in `/etc/yum.repos.d/` even after the COPR metadata is gone. Inspect the directory. |
| "I'll validate the Brewfile with `brew bundle check`." | That evaluates PR-controlled Ruby. Use the fail-closed `build/validate-brewfiles.sh` instead. |
| "The documentation says images are signed." | Signing is disabled in this scope; that claim would be false. |

## Red Flags

- Reaching for a full image build before the cheap checks, or making a build a
  prerequisite for a docs/syntax fix
- Ignoring a `bootc container lint --fatal-warnings` warning instead of fixing it
- Manually editing a `Containerfile` digest that Renovate manages
- Leaving a COPR or third-party repo file enabled after install
- Validating a Brewfile with `brew bundle check` instead of the safe validator
- Adding a workflow or route that assumes `pr-validation.yml` or
  `projectbluefin/actions`
- Documenting images as signed while cosign signing is disabled

## Verification

- [ ] Did you identify the correct category (build/lint, CI, runtime, Renovate, COPR, ujust)?
- [ ] Did you check the symptom against the real file before editing?
- [ ] Did the light checks pass (`just check`, `just lint`, `bats tests/unit`, `git diff --check`)?
- [ ] If the change touches Brewfiles, did `bash build/validate-brewfiles.sh custom/brew` pass without evaluating Ruby?
- [ ] If the change touches `ci/jenkins/`, did `bash ci/jenkins/tests/run-all.sh` pass?
- [ ] Did you confirm the fix without requiring a local full image build?
