---
name: finpilot-pr-checklist
description: >-
  PR gates and pre-commit checklist by change type for bluefin-cosmic-dx.
  Separates light local validation from the image builds owned by GitHub Actions
  and Jenkins. Use before opening or reviewing a pull request.
---

# bluefin-cosmic-dx PR Checklist

## When to Use

- Before opening a new pull request
- Before pushing changes that modify build scripts, CI workflows, or runtime files
- When reviewing a PR and checking the author ran the right validation
- When deciding which checks belong to the contributor and which belong to CI

## When NOT to Use

- The PR is documentation-only with no build/CI impact — run the light checks,
  but the full per-change list is overkill
- You are troubleshooting an already-open PR — use `finpilot-troubleshooting`
- You need the mechanics behind a check — use `finpilot-build`, `finpilot-ci`, or `finpilot-custom`

## Core Process

0. **Check for an existing open PR against the same issue** — run
   `gh pr list --state open --search "<issue-number>"` and skim
   `gh pr list --state open`. If a PR already addresses the issue, review or
   extend it instead of opening a competing one.
1. **Identify which files changed**
2. **Run the light validation** for that change type (tables below)
3. **Fix every error before opening the PR**
4. **Leave the full image build to CI/Jenkins** — it is not a local gate here
5. **Open the PR to `main`** with a Conventional Commit title and let the PR
   checks run

## Pre-Commit Checklist (Applies to ALL Commits)

### 1. Conventional Commits

Commit messages and PR titles must follow:

```
<type>[optional scope]: <description>
```

Valid types: `feat`, `fix`, `docs`, `chore`, `build`, `ci`, `refactor`, `test`

### 2. shellcheck

Run shellcheck on modified shell files:

```bash
just lint                          # shellcheck across all *.sh
# or target one file
shellcheck -x build/10-build.sh
```

Fix every error. `validate-shellcheck.yml` is a hard block.

### 3. YAML Validation

Parse modified YAML before committing:

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/your-file.yml'))"
```

### 4. Justfile Syntax

```bash
just check    # just --unstable --fmt --check for the Justfile and *.just files
```

### 5. Whitespace

```bash
git diff --check
```

## Light Validation vs Build Validation

Run the light checks locally. The full image build and its strict lint gate
belong to CI/Jenkins and are only run locally when a capable machine is
available.

| Validation | Run locally? | Command / where it runs |
| --- | --- | --- |
| Whitespace | Yes | `git diff --check` |
| Shell syntax | Yes | `just lint` / `shellcheck -x` |
| Just syntax | Yes | `just check` |
| BATS static unit tests | Yes | `bats tests/unit` (tests read files; no image build) |
| Brewfile safety | Yes (needs `brew`) | `bash build/validate-brewfiles.sh custom/brew` |
| Jenkins shell tests | Yes | `bash ci/jenkins/tests/run-all.sh` |
| Renovate config | When it changed | `renovate-config-validator --strict` |
| YAML / actionlint | When possible | `python3 -c "import yaml; ..."`, `actionlint` if installed |
| Full image build + `bootc container lint --fatal-warnings` | **No** — CI/Jenkins | `.github/workflows/build.yml` PR check; Jenkins `ci/jenkins/Jenkinsfile.stable` / `Jenkinsfile.nvidia` |
| VM/ISO installer artifacts | No — only on a capable local machine | `iso/*.toml` (local testing); never required for a docs or syntax change |

Do not make a full image build a prerequisite for a documentation, workflow, or
script-syntax change. The strict lint gate (`--fatal-warnings`) runs inside the
image build and treats every warning as a failure.

## Change-Type Checklists

### `Containerfile` / `Justfile` Changes

| Check | Command / note |
| --- | --- |
| Whitespace and diff hygiene | `git diff --check` |
| `ARG BASE_IMAGE` preserved | The default (Bluefin DX) and the `--build-arg` used by Jenkins must still line up |
| Final lint step preserved | `bootc container lint --fatal-warnings` stays the last Containerfile step |
| Justfile formatting | `just check` |
| Full image build | Deferred to `.github/workflows/build.yml` and Jenkins |

### `build/*.sh` Changes

| Check | Command / note |
| --- | --- |
| shellcheck | `just lint` or `shellcheck -x build/<script>.sh` |
| BATS unit tests | `bats tests/unit` |
| Discovery glob | New numbered scripts must match `/ctx/build/[1-9][0-9]*-*.sh` |
| COPR isolation | `copr_install_isolated` used; no COPR left enabled |
| Third-party repo cleanup | Repo file removed at the end of the script |
| `dnf5` only | No `dnf`, `yum`, or `rpm-ostree` |

### Brewfile Changes (`custom/brew/*.Brewfile`)

| Check | Command / note |
| --- | --- |
| Safe validation | `just validate-brewfiles` or `bash build/validate-brewfiles.sh custom/brew` |
| Literal declarations | No interpolation, trailing arguments, or non-literal taps |
| Package exists | The validator passes names to `brew info` as data |
| Never | `brew bundle check --file <untrusted>` — it evaluates PR-controlled Ruby |

**CI trigger:** `validate-brewfiles.yml`

### Flatpak Changes (`custom/flatpaks/*.preinstall`)

| Check | Command / note |
| --- | --- |
| App ID on Flathub | Visit `https://flathub.org/apps/<app-id>` |
| INI format | `[Flatpak Preinstall <app-id>]` with `Branch=stable` |
| No duplicates | Search existing `.preinstall` files |

**CI trigger:** `validate-flatpaks.yml`

### ujust Changes (`custom/ujust/*.just`)

| Check | Command / note |
| --- | --- |
| Format/syntax | `just check`, or `just --unstable --fmt --check -f custom/ujust/<file>.just` |
| No system package manager | `grep -nE "dnf5?|rpm-ostree|yum" custom/ujust/*.just` should return nothing |
| Matching Brewfile shortcut | Every shipped `*.Brewfile` has a `ujust` recipe |

**CI trigger:** `validate-justfiles.yml`

### Workflow / CI Changes (`.github/workflows/`, `.github/renovate.json5`)

| Check | Command / note |
| --- | --- |
| YAML parses | `python3 -c "import yaml; yaml.safe_load(open('<file>'))"` |
| Actionlint | `actionlint .github/workflows/*.yml` if installed |
| Actions pinned | New `uses:` entries pinned to a commit SHA with a version comment |
| Renovate config | `renovate-config-validator --strict` when Renovate changes |
| No upstream workflows | Do not reference `pr-validation.yml` or `build-image.yml`; they do not exist here |

**CI triggers:** the matching `validate-*.yml`, plus `build.yml` on any PR to `main`

### Jenkins Changes (`ci/jenkins/`)

| Check | Command / note |
| --- | --- |
| Shell tests | `bash ci/jenkins/tests/run-all.sh` |
| Branch gating | Publish/release stay gated on `EFFECTIVE_BRANCH == DEFAULT_BRANCH` (`main`) |
| Variant mechanism | NVIDIA uses `--build-arg BASE_IMAGE=...`, not an extra activation script |
| Signing | Do not add signing steps; cosign signing is disabled here |

**CI trigger:** `validate-jenkins-tests.yml`

### README / Documentation / Skills

| Check | Command / note |
| --- | --- |
| Links resolve | Check relative links to `AGENTS.md`, `.agents/skills/`, `docs/` |
| Raptor section | Update "What Makes this Raptor Different?" when packages or configuration change |
| Signing wording | Never document images as signed |
| Skill frontmatter | `name` must match the skill directory; list new skills in the router and README |

## PR Status Check Reference

| Workflow | Trigger path | Required? |
| --- | --- | --- |
| `build.yml` | Any PR to `main` | Yes (image build PR check; does not publish) |
| `unit-tests.yml` | `build/**`, `custom/**`, `tests/**`, `Justfile` | Yes |
| `validate-shellcheck.yml` | `build/**/*.sh` | Yes |
| `validate-brewfiles.yml` | `custom/brew/**` | Yes |
| `validate-flatpaks.yml` | `custom/flatpaks/**` | Yes |
| `validate-justfiles.yml` | `Justfile`, `custom/ujust/**` | Yes |
| `validate-renovate.yml` | `.github/renovate.json5`, `.github/workflows/renovate.yml` | Yes |
| `validate-jenkins-tests.yml` | `ci/jenkins/**` | Yes when Jenkins changes |

All required checks must pass before merge. There is no `pr-validation.yml`
here, so do not require it in branch protection.

## Common Rationalizations

| Rationalization | Reality |
| --- | --- |
| "I'll skip shellcheck locally — CI will catch it." | CI catches it, but the fix loop is slower and clogs the queue. `just lint` takes seconds. |
| "I only changed one line in a workflow — it does not need parsing." | YAML is fragile; `yaml.safe_load` and, when available, `actionlint` catch different classes of error. |
| "I'll run a full image build to be safe before opening the PR." | CI/Jenkins owns the image build. Run the light checks; save the heavy build for when it is actually needed. |
| "I'll fix the Brewfile syntax after the PR is open." | `validate-brewfiles.yml` blocks the PR. Use the safe validator first. |
| "The PR is small — the whole checklist is needed." | The checklist is weighted by change type. Run the relevant section plus the all-commits list. |
| "The required check is `pr-validation`." | That check does not exist here; require the checks that do (`BATS unit tests`, `validate`, `Build and push image`). |

## Red Flags

- A PR opened with shellcheck failures or unparsed YAML
- A Brewfile validated with `brew bundle check` instead of the safe validator
- A Flatpak app ID added without verifying it on Flathub
- `dnf5`, `dnf`, `yum`, or `rpm-ostree` inside a `custom/ujust/*.just` recipe
- A workflow referencing `pr-validation.yml`, `build-image.yml`, or a `stable` branch
- A new action `uses:` on a floating tag instead of a pinned SHA
- Documentation claiming images are signed
- Treating the full image build as a local prerequisite for a docs or syntax change

## Verification

- [ ] Do the commits and PR title follow Conventional Commits?
- [ ] Did `just lint` (shellcheck), `just check`, and `git diff --check` pass?
- [ ] Did the change-type checks for the modified files pass?
- [ ] Did `bats tests/unit` pass when `build/**`, `custom/**`, `tests/**`, or the `Justfile` changed?
- [ ] Did `bash build/validate-brewfiles.sh custom/brew` pass (without evaluating Ruby) when Brewfiles changed?
- [ ] Did `bash ci/jenkins/tests/run-all.sh` pass when `ci/jenkins/` changed?
- [ ] Were the full image build and `bootc container lint --fatal-warnings` left to CI/Jenkins rather than required locally?
- [ ] Is the README raptor section updated when packages or configuration changed?
