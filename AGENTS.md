# Copilot Instructions for bluefin-cosmic-dx bootc Image Template

## CRITICAL: GitHub API Usage

**ALWAYS use GitHub API for external references:**

- When researching other repositories (e.g., projectbluefin/distroless, ublue-os/bluefin)
- When checking Containerfiles, build scripts, or configuration files
- Use the `github-mcp-server-get_file_contents` tool instead of curl/wget
- This ensures consistent, authenticated access and better error handling

## CRITICAL: Pre-Commit Checklist

**Execute before EVERY commit:**

1. **Conventional Commits** - ALL commits MUST follow conventional commit format (see below)
2. **Shellcheck** - `shellcheck *.sh` (or `just lint`) on all modified shell files
3. **YAML validation** - `python3 -c "import yaml; yaml.safe_load(open('file.yml'))"` on all modified YAML
4. **Justfile syntax** - `just check`
5. **Unit tests** - `bats tests/unit/` (or `just test-unit`) when `build/`, `custom/`, `tests/` or the `Justfile` change
6. **Whitespace** - `git diff --check`
7. **Confirm with user** - Always confirm before committing and pushing

**Never commit files with syntax errors.**

**A full container image build is NOT part of the local pre-commit gate.** The
image build and `bootc container lint --fatal-warnings` run in Jenkins; GitHub
Actions runs the PR checks. Run the light checks above and leave the heavy build
to CI. See "Light validation" below.

### REQUIRED: Conventional Commit Format

**ALL commits MUST use conventional commits format**

```
<type>[optional scope]: <description>
```

## Agent Skills (`.agents/skills`)

This repository ships discoverable Agent Skills under `.agents/skills/`. Each
skill lives in a lowercase directory with a `SKILL.md` whose `name` frontmatter
matches the directory.

- Start at `.agents/skills/README.md` for the skill index.
- Use `.agents/skills/finpilot-router/SKILL.md` as the single canonical
  "I need to… → which skill?" routing table. Do not duplicate that table here.
- `finpilot-build` covers `Containerfile`/`Justfile`/`build/*.sh`;
  `finpilot-ci` covers Jenkins, GitHub Actions and Renovate;
  `finpilot-custom` covers Brewfiles, Flatpaks and ujust;
  `finpilot-packages` is the package decision tree; `finpilot-pr-checklist`
  holds the light validation gate.
- When adding, renaming or removing a skill, update `.agents/skills/README.md`
  and the router table together.

## CI Surfaces, Base Image and Release

- **GitHub Actions = PR and light validation only.** The workflows under
  `.github/workflows/` (`build.yml` image build as a PR check, `unit-tests.yml`,
  `validate-*.yml`, `renovate.yml`, `clean.yml`) never publish images.
- **Jenkins = production build, publication and signing.**
  `ci/jenkins/Jenkinsfile.stable` (standard) and
  `ci/jenkins/Jenkinsfile.nvidia` (NVIDIA) build with Docker, push to GHCR,
  sign the published digest with Cosign, create GitHub releases and notify n8n.
  Both are gated on `main`; full setup is in `docs/jenkins/README.md`.
- **Base image = Bluefin DX via `ARG BASE_IMAGE`.** `Containerfile` defaults to
  `ghcr.io/ublue-os/bluefin-dx:stable`. The NVIDIA variant is the *same*
  Containerfile built with
  `--build-arg BASE_IMAGE=ghcr.io/ublue-os/bluefin-dx-nvidia-open:stable-daily`;
  there is no separate NVIDIA activation script.
- **Renovate** runs from `.github/workflows/renovate.yml` every 6 hours using
  the built-in `secrets.GITHUB_TOKEN` (there is no `RENOVATE_TOKEN`).
- **Cosign signing happens in Jenkins.** Both pipelines sign the published
  digest (`IMAGE_REPOSITORY@sha256:<digest>`) with a traditional Cosign key in a
  `Sign Image` stage gated on `main`, using the Jenkins credentials `cosign_key`
  (`Secret file`) and `cosign_pass` (`Secret text`). `cosign.pub` is versioned
  for `cosign verify`. `build.yml` triggers on pull requests only, so it never
  publishes or signs. Attestations, SBOM, provenance and rechunking stay out of
  scope.
- **Light validation, no required local build.** Run `shellcheck`/`just lint`,
  `just check`, `bats tests/unit`, YAML parsing, the Jenkins shell tests and
  `git diff --check` locally. The image build and
  `bootc container lint --fatal-warnings` are CI/Jenkins responsibilities.

## CRITICAL: Template Initialization

**When this repository is used as a template, you MUST:**

### 1. Rename ALL instances of `bluefin-cosmic-dx`

**Source of truth**: the `# Name:` comment and the `IMAGE_NAME`/`IMAGE_VENDOR`
ARGs in `Containerfile`. Use semantic references, not line numbers.

**Files to update:**

- `Containerfile` (the `# Name:` comment and the identity ARGs)
- `Justfile` (`image_name` and `image_name_nvidia`)
- `README.md` (title, GHCR badges and bootc switch examples)
- `README.pt-BR.md` (same fields in Portuguese)
- `artifacthub-repo.yml` (`repositoryID` and owner fields)
- `custom/ujust/README.md` (bootc switch example)
- `.github/workflows/clean.yml` (`packages:`)
- `iso/iso.toml` and `iso/iso-nvidia.toml` (bootc switch URLs)
- `AGENTS.md` (identity references)

### 2. Create "What's Different" section in README

**CRITICAL**: Add this section near the top of README.md (after the title/intro, before detailed docs):

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

*Last updated: [date]*
```

**Maintenance requirement**:

- **ALWAYS update this section when you modify packages or configuration**
- Keep descriptions brief and user-focused (explain "why", not just "what")
- Write for typical Linux users, not developers
- Update the "Last updated" date with each change

### 3. Verify copilot instructions are present

Confirm `.github/copilot-instructions.md` exists in the new repository. This file should be automatically copied when using this as a GitHub template.

### 4. Confirm the signing state

Cosign signing is handled by the **Jenkins** production pipelines. Keep the
documentation accurate: Jenkins signs the published digest with a traditional
key, while GitHub Actions triggers on pull requests only and never publishes or
signs. The private key lives in the Jenkins `cosign_key` credential (`Secret
file`) with its password in `cosign_pass` (`Secret text`); `cosign.pub` is
versioned for verification. Attestations, SBOM, provenance and rechunking stay
out of scope.

**These 4 steps are REQUIRED for every new template instance.**

---

## Repository Structure

```
├── Containerfile          # Multi-stage build; ARG BASE_IMAGE selects the base
├── Justfile              # Local build/VM recipes (image name, build commands)
├── build/                # Build-time scripts, numbered and auto-run in order
│   ├── 00-image-info.sh # Writes image-info.json / os-release identity
│   ├── 10-build.sh      # Main script; runs numbered [1-9][0-9]*-*.sh scripts
│   ├── 15-system-optimizations.sh
│   ├── 20-third-party-repos.sh
│   ├── 30-cosmic-desktop.sh
│   ├── 40-remove-gnome.sh
│   ├── 99-versions.sh
│   ├── clean-stage.sh   # Pre-lint cleanup
│   ├── copr-helpers.sh  # COPR isolation helpers
│   └── validate-*.sh    # Brewfile/Flatpak validators
├── custom/               # Runtime layer (installed at runtime/first boot)
│   ├── brew/            # Homebrew Brewfiles
│   ├── flatpaks/        # Flatpak preinstall (INI format)
│   ├── system-files/    # System configs copied in at build time
│   └── ujust/           # User commands (Brewfile/Flatpak shortcuts)
├── iso/                  # Local testing only (no CI/CD)
│   ├── disk.toml        # VM/disk image config (QCOW2/RAW)
│   ├── iso.toml         # Standard ISO installer config (bootc switch URL)
│   ├── iso-nvidia.toml  # NVIDIA ISO installer config
│   └── rclone/          # Upload configs (Cloudflare R2, AWS S3, etc.)
├── ci/jenkins/           # Production pipelines (stable + nvidia) and tests
├── tests/unit/           # BATS unit tests (static; no image build)
├── docs/                 # Docs, including docs/jenkins/README.md and plans
├── .agents/skills/       # Agent Skills (see "Agent Skills" above)
├── .github/              # GitHub configuration and CI
│   ├── workflows/       # GitHub Actions PR checks and Renovate
│   │   ├── build.yml               # PR check only (no publish)
│   │   ├── unit-tests.yml          # BATS unit tests
│   │   ├── clean.yml               # Deletes images >90 days old
│   │   ├── renovate.yml            # Renovate bot updates (6h interval)
│   │   └── validate-*.yml          # Pre-merge validation checks
│   ├── copilot-instructions.md  # Pointer to AGENTS.md
│   ├── SETUP_CHECKLIST.md       # Quick setup checklist for users
│   ├── commit-convention.md     # Conventional commits guide
│   └── renovate.json5           # Renovate configuration
├── .dockerignore          # Keeps the build context minimal
├── .pre-commit-config.yaml   # Pre-commit hooks (optional local use)
└── .gitignore                # Prevents committing secrets (cosign.key, etc.)
```

---

## Core Principles

### Multi-Stage Build Architecture

This image follows the **Bluefin architecture pattern** from @projectbluefin/distroless:

**Architecture Layers:**

1. **Context Stage (ctx)** - Combines resources from multiple sources:
   - Local build scripts (`/build`)
   - Local custom files (`/custom`)
   - **@projectbluefin/common** - Desktop configuration shared with Aurora (`/oci/common`)
   - **@ublue-os/brew** - Homebrew integration (`/oci/brew`)

2. **Base Image - Bluefin DX selected by `ARG BASE_IMAGE`:**
   - Standard: `ghcr.io/ublue-os/bluefin-dx:stable` (default, set by the global ARG)
   - NVIDIA: `ghcr.io/ublue-os/bluefin-dx-nvidia-open:stable-daily` (same Containerfile, `--build-arg BASE_IMAGE=...`)

   The `Containerfile` also lists disabled alternative FROM lines (for example
   `ghcr.io/ublue-os/base-main:latest` and
   `quay.io/centos-bootc/centos-bootc:stream10`); they are comments, not the
   built image. Do not document them as the default.

**OCI Container Resources:**

- Resources from OCI containers are copied to **distinct subdirectories** (`/oci/*`) to avoid file conflicts
- Renovate can update the `:latest` tags in the `ctx` stage to **SHA digests** for reproducibility
- All OCI resources are mounted at build-time via the `ctx` stage

**Reference:** See [Bluefin Contributing Guide](https://docs.projectbluefin.io/contributing/) for architecture diagram

### Build-time vs Runtime

- **Build-time** (`build/`): Baked into container. Use `dnf5 install`. Services, configs, system packages. `custom/system-files/` is also copied into the image here.
- **Runtime** (`custom/brew/`, `custom/flatpaks/`, `custom/ujust/`): User installs after deployment. Use Brewfiles, Flatpaks. CLI tools, GUI apps, dev environments.

### Bluefin Convention Compliance

**ALWAYS follow @ublue-os/bluefin patterns. Confirm before deviating.**

- Use `dnf5` exclusively (never `dnf`, `yum`, `rpm-ostree`)
- Always `-y` flag for non-interactive
- COPRs: enable → install → **DISABLE** (critical, prevents repo persistence)
- Use `copr_install_isolated` from `build/copr-helpers.sh` (sourced as `/ctx/build/copr-helpers.sh`)
- Numbered scripts auto-run: `10-build.sh` executes `/ctx/build/[1-9][0-9]*-*.sh` in order (for example `15-system-optimizations.sh`, `20-third-party-repos.sh`, `30-cosmic-desktop.sh`, `40-remove-gnome.sh`). No rename or Containerfile edit is needed to activate one.
- Check @bootc-dev for container best practices

### Branch Strategy

- **main** = Production releases ONLY. Never push directly. Jenkins builds and publishes `:stable` images from it.
- **Conventional Commits** = REQUIRED. `feat:`, `fix:`, `chore:`, etc.
- **Workflows** = GitHub Actions performs PR checks and light validation only; the official image build/publish is handled by Jenkins pipelines (`ci/jenkins/Jenkinsfile.stable` and `ci/jenkins/Jenkinsfile.nvidia`).

### Validation Workflows

The repository includes automated validation on pull requests:

- **build.yml** - Builds the image as a PR check (does not publish)
- **unit-tests.yml** - Runs the BATS suite in `tests/unit/`
- **validate-shellcheck.yml** - Runs shellcheck on all `build/*.sh` scripts
- **validate-brewfiles.yml** - Validates Homebrew Brewfile syntax
- **validate-flatpaks.yml** - Checks Flatpak app IDs exist on Flathub
- **validate-justfiles.yml** - Validates just file syntax
- **validate-renovate.yml** - Validates Renovate configuration
- **validate-jenkins-tests.yml** - Runs the Jenkins shell tests in `ci/jenkins/tests/`

**When adding files**: These validations run automatically on PRs. Fix any errors before merge.

### Light validation (no local build required)

Run the light checks locally; leave the full image build and
`bootc container lint --fatal-warnings` to GitHub Actions/Jenkins:

```bash
just check                                        # Justfile and *.just syntax
just lint                                         # shellcheck across *.sh
bats tests/unit/                                  # static BATS unit tests
bash build/validate-brewfiles.sh custom/brew      # Brewfile safety
bash ci/jenkins/tests/run-all.sh                  # Jenkins shell tests
git diff --check                                  # whitespace
```

The BATS suite reads files only (for example
`tests/unit/containerfile-hardening_test.bats`) and never starts a build. A
full `just build` / `just build-nvidia` is optional locally.

---

## Where to Add Packages

This section provides clear guidance on where to add different types of packages.

### System Packages (dnf5 - Build-time)

**Location**: `build/10-build.sh` (base packages) or a numbered `build/NN-*.sh` script

System packages are installed at build-time and baked into the container image.
Use `dnf5` exclusively.

**Example**:

```bash
# In build/10-build.sh, or a numbered build/NN-*.sh script
dnf5 install -y vim git htop neovim tmux
```

**When to use**:

- System utilities and services
- Dependencies required for other build-time operations
- Packages that need to be available immediately on first boot
- Services that need to be enabled with `systemctl enable`

**Important**:

- Always use `dnf5` (never `dnf`, `yum`, or `rpm-ostree`)
- Always add `-y` flag for non-interactive installs
- For COPR repositories, use `copr_install_isolated` and disable after use
- For third-party repos, see the live example `build/20-third-party-repos.sh`

**Script Naming Convention**:

- `10-build.sh` - Main build script (always runs first)
- `NN-*.sh` (e.g. `15-`, `20-`, `30-`, `40-`) - Additional scripts, auto-run in numerical order by `10-build.sh` when they match `/ctx/build/[1-9][0-9]*-*.sh`
- There is **no `.example` activation step** in this repository: create a numbered script and it runs. To disable one, rename it so it no longer matches `/ctx/build/[1-9][0-9]*-*.sh` (for example `20-script.sh.disabled`) or remove the file; removing execute permission does **not** disable it, because `10-build.sh` invokes every matching file with `bash` regardless of its mode (see `build/README.md`).

### Homebrew Packages (Brew - Runtime)

**Location**: `custom/brew/*.Brewfile`

Homebrew packages are installed by users after deployment. Best for CLI tools and development environments.

**Files**:

- `custom/brew/default.Brewfile` - General purpose CLI tools (the only Brewfile committed today)
- Create additional `*.Brewfile` files as needed, then wire them to a `ujust` shortcut

**Example**:

```ruby
# In custom/brew/default.Brewfile
brew "bat"        # cat with syntax highlighting
brew "eza"        # Modern replacement for ls
brew "ripgrep"    # Faster grep
brew "fd"         # Simple alternative to find
```

**When to use**:

- CLI tools and utilities
- Development tools (node, python, go, etc.)
- User-specific tools that don't need to be in the base image
- Tools that update frequently

**Important**:

- Brewfiles use Ruby syntax
- Users install via `ujust` commands (e.g., `ujust install-default-apps`)
- Not installed in ISO/container - users install after deployment

### Flatpak Applications (GUI Apps - Runtime)

**Location**: `custom/flatpaks/*.preinstall`

Flatpak applications are GUI apps installed after first boot. Use INI format.

**Files**:

- `custom/flatpaks/default.preinstall` - Default GUI applications (the only preinstall file today)
- Create additional `*.preinstall` files as needed

**Example**:

```ini
# In custom/flatpaks/default.preinstall
[Flatpak Preinstall org.mozilla.firefox]
Branch=stable

[Flatpak Preinstall com.visualstudio.code]
Branch=stable

[Flatpak Preinstall org.gnome.Calculator]
Branch=stable
```

**When to use**:

- GUI applications
- Desktop apps (browsers, editors, media players)
- Apps that users expect to have immediately available
- Apps from Flathub (<https://flathub.org/>)

**Important**:

- Installed post-first-boot (not in ISO/container)
- Requires internet connection
- Find app IDs at <https://flathub.org/>
- Use INI format with `[Flatpak Preinstall APP_ID]` sections
- Always specify `Branch=stable` (or another branch)

---

## Quick Reference: Common User Requests

| Request | Action | Location |
|---------|--------|----------|
| Add package (build-time) | `dnf5 install -y pkg` | `build/10-build.sh` |
| Add package (runtime) | `brew "pkg"` | `custom/brew/default.Brewfile` |
| Add GUI app | `[Flatpak Preinstall org.app.id]` | `custom/flatpaks/default.preinstall` |
| Add user command | Create shortcut (NO dnf5) | `custom/ujust/*.just` |
| Add third-party repo | Follow the live example | `build/20-third-party-repos.sh` |
| Replace desktop | Numbered build script | `build/30-cosmic-desktop.sh`, `build/40-remove-gnome.sh` |
| Switch base image | Change `ARG BASE_IMAGE` (or pass `--build-arg`) | `Containerfile` |
| Add OCI containers | Add `COPY --from=` lines | `Containerfile` `ctx` stage |
| Test locally (light) | `just check && just lint && bats tests/unit/` | Terminal |
| Test locally (full, optional) | `just build && just build-qcow2 && just run-vm-qcow2` | Terminal |
| Deploy (production) | `sudo bootc switch ghcr.io/ericrocha97/bluefin-cosmic-dx:stable` | Terminal |
| Enable service | `systemctl enable service.name` | `build/10-build.sh` |
| Add COPR | enable → install → **DISABLE** | `build/10-build.sh` |
| Validate changes | Local light checks + PR workflows | `.github/workflows/validate-*.yml` |

---

## Detailed Workflows

### 1. Multi-Stage Build Architecture

**File**: `Containerfile`

This image uses a **multi-stage build** following the @projectbluefin/distroless pattern.

**Stage 1: Context (ctx)**
Combines local resources and the imported OCI containers actually used here:

```dockerfile
ARG BASE_IMAGE=ghcr.io/ublue-os/bluefin-dx:stable

FROM scratch AS ctx

COPY build /build
COPY custom /custom
# Import from OCI containers - Renovate can update :latest to SHA-256 digests
COPY --from=ghcr.io/projectbluefin/common:latest /system_files /oci/common
COPY --from=ghcr.io/ublue-os/brew:latest /system_files /oci/brew
```

**Stage 2: Base Image**

```dockerfile
FROM ${BASE_IMAGE}
```

**Variants** (the same Containerfile, different `BASE_IMAGE` value):

```dockerfile
ghcr.io/ublue-os/bluefin-dx:stable                  # Standard (default)
ghcr.io/ublue-os/bluefin-dx-nvidia-open:stable-daily # NVIDIA (`just build-nvidia`)
```

The `Containerfile` contains commented alternative `FROM` lines (for example
`ghcr.io/ublue-os/base-main:latest`,
`quay.io/centos-bootc/centos-bootc:stream10`). They are examples, not the built
defaults.

**Renovate**: the `Containerfile`/`Justfile` images are tracked by Renovate every 6 hours using `secrets.GITHUB_TOKEN` (see `.github/renovate.json5` and `.github/workflows/renovate.yml`).

**OCI Container Resources:**

- **@projectbluefin/common** - Desktop configuration shared with Aurora
- **@ublue-os/brew** - Homebrew integration

**File Locations in Build Scripts:**

- Local build scripts: `/ctx/build/`
- Local custom files: `/ctx/custom/`
- Common files: `/ctx/oci/common/`
- Brew files: `/ctx/oci/brew/`

### 2. OCI Containers for Additional System Files

**File**: `Containerfile` (ctx stage)

The `ctx` stage already imports `@projectbluefin/common` and `@ublue-os/brew`.
To layer in additional system files from OCI containers, add more
`COPY --from=` lines to the `ctx` stage and copy the files into place from a
build script.

**What's included**:

- `projectbluefin/common:latest` - Desktop configuration shared with Aurora
- `ublue-os/brew:latest` - Homebrew system integration files

**When to use**:

- You want additional system integration beyond what the base image provides
- You're building a Bluefin derivative and want to maintain brand consistency

**Important**:

- Any new OCI source must exist and be reachable at build time; do not invent tags
- The files are mounted into the build scripts under `/ctx/oci/*`
- To use them, copy from `/ctx/oci/*` to the appropriate system location in a build script

### 3. Build Scripts (`build/`)

**Pattern**: The `Containerfile` runs `10-build.sh`; that script runs numbered files (`15-system-optimizations.sh`, `20-third-party-repos.sh`, `30-cosmic-desktop.sh`, `40-remove-gnome.sh`, …) in order. No `.example` renaming step.

**Example - `build/10-build.sh`**:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Install packages
dnf5 install -y vim git htop neovim

# Enable services
systemctl enable podman.socket

# Download binaries
curl -L https://example.com/tool -o /usr/local/bin/tool
chmod +x /usr/local/bin/tool
```

**Example - third-party RPM repos** (see `build/20-third-party-repos.sh`):

```bash
#!/usr/bin/env bash
set -euo pipefail

# Add the vendor repo, install, then remove the repo file
cat > /etc/yum.repos.d/vendor.repo << 'EOF'
[vendor]
name=vendor
baseurl=https://example.com/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://example.com/linux_signing_key.pub
EOF

dnf5 install -y vendor-package
rm -f /etc/yum.repos.d/vendor.repo   # required cleanup
```

**Example - COPR pattern** (source the helper at `/ctx/build/copr-helpers.sh`):

```bash
#!/usr/bin/env bash
set -euo pipefail

source /ctx/build/copr-helpers.sh

# COPR (isolated - enabled only for this install, then disabled)
copr_install_isolated "owner/repo" package-name
```

**Example - Desktop change** (see `build/30-cosmic-desktop.sh` and `build/40-remove-gnome.sh`):

```bash
#!/usr/bin/env bash
set -euo pipefail

# Install COSMIC (isolated COPR), then remove GNOME and switch the session
copr_install_isolated "ryanabx/cosmic-epoch" cosmic-session cosmic-comp
systemctl set-default graphical.target
```

**CRITICAL**: Use `copr_install_isolated` and always disable COPRs afterwards.

**Live examples**: Read `build/20-third-party-repos.sh`, `build/30-cosmic-desktop.sh`, and `build/40-remove-gnome.sh` before writing a new pattern. There are no `.example` scripts in this repository.

### 4. Homebrew (`custom/brew/`)

**Files**: `*.Brewfile` (Ruby syntax)

**Example - `custom/brew/default.Brewfile`**:

```ruby
# CLI tools
brew "bat"        # Better cat
brew "eza"        # Better ls
brew "ripgrep"    # Better grep
brew "fd"         # Better find

# Dev tools
tap "homebrew/cask"
brew "node"
brew "python"
```

**Users install via**: `ujust install-default-apps` (see `custom/ujust/custom-apps.just`)

### 5. ujust Commands (`custom/ujust/`)

**Files**: `*.just` (all consolidated into the image's ujust recipes)

**Example - `custom/ujust/custom-apps.just`**:

```just
# Install the default Brewfile
[group('Apps')]
install-default-apps:
    #!/usr/bin/env bash
    set -euo pipefail
    brew bundle --file /usr/share/ublue-os/homebrew/default.Brewfile
```

**RULES**:

- **NEVER** use `dnf5` in ujust - only Brewfile/Flatpak shortcuts
- Use `[group('Category')]` for organization
- Every shipped `*.Brewfile` should have a matching `ujust` shortcut

### 6. Flatpaks (`custom/flatpaks/`)

**Files**: `*.preinstall` (INI format, installed after first boot)

**Example - `custom/flatpaks/default.preinstall`**:

```ini
[Flatpak Preinstall org.mozilla.firefox]
Branch=stable

[Flatpak Preinstall org.gnome.Calculator]
Branch=stable

[Flatpak Preinstall com.visualstudio.code]
Branch=stable
```

**Important**: Not in ISO/container. Installed post-first-boot. Requires internet. Find IDs at <https://flathub.org/>

### 7. ISO/Disk Images (`iso/`)

**For local testing only. No CI/CD.**

**Files**:

- `iso/disk.toml` - VM images (QCOW2/RAW): `just build-qcow2`
- `iso/iso.toml` - Standard installer ISO: `just build-iso`
- `iso/iso-nvidia.toml` - NVIDIA installer ISO: `just build-nvidia-iso`

**CRITICAL** - Keep the bootc switch URL in `iso/iso.toml` and
`iso/iso-nvidia.toml` matching this repository:

```toml
[customizations.installer.kickstart]
contents = """
%post
bootc switch --mutate-in-place --transport registry ghcr.io/ericrocha97/bluefin-cosmic-dx:stable
%end
"""
```

**Upload**: Use `iso/rclone/` configs (Cloudflare R2, AWS S3, Backblaze B2, SFTP)

### 8. Release Workflow

**Branches**:

- `main` - Production only. Jenkins builds and publishes `:stable` images from it. Never push directly.

**Publication (Jenkins)**:

- `ci/jenkins/Jenkinsfile.stable` - standard image `ghcr.io/ericrocha97/bluefin-cosmic-dx` (weekly, `H 2 * * 0`)
- `ci/jenkins/Jenkinsfile.nvidia` - NVIDIA image `ghcr.io/ericrocha97/bluefin-cosmic-dx-nvidia` (daily, `H 10 * * *`)
- Both build with Docker, push to GHCR, create a GitHub release and notify n8n; publish/release stages are gated on `main`.
- Full setup lives in `docs/jenkins/README.md`.

**GitHub Actions (PR/light validation only)**:

- `build.yml` - PR check only (does not publish the image)
- `unit-tests.yml` - BATS unit tests
- `renovate.yml` - Self-hosted Renovate, every 6 hours
- `clean.yml` - Deletes GHCR images >90 days (weekly)
- `validate-*.yml` - Pre-merge validation (shellcheck, Brewfile, Flatpak, justfiles, Renovate, Jenkins tests)

**Image Tags** (created by Jenkins):

- `:stable` - Latest stable release from `main`
- `:stable.YYYYMMDD` - Datestamped stable release
- `:YYYYMMDD` - Date only

`pr-*` and `sha-*` tags are not published by this repository; PR checks build
without pushing. The NVIDIA release tag is `v<date>-nvidia`.

**Renovate Bot**:

- Runs from `.github/workflows/renovate.yml` using the built-in `secrets.GITHUB_TOKEN` (no `RENOVATE_TOKEN`)
- Updates tracked container images/digests in `Containerfile` and `Justfile` (see `.github/renovate.json5`)
- Runs every 6 hours; review and merge its PRs to keep images current

### 9. Understanding the Multi-Stage Build Architecture

This image implements a **multi-stage build pattern** following @projectbluefin/distroless.

**Why Multi-Stage?**

- **Modularity**: Combine resources from multiple OCI containers
- **Reusability**: Share common components across different images
- **Maintainability**: Update shared components independently
- **Reproducibility**: Renovate can update OCI container tags to SHA digests

**Stage Breakdown:**

**Stage 1: Context (ctx)**

```dockerfile
FROM scratch AS ctx
COPY build /build                    # Local build scripts
COPY custom /custom                  # Local customizations
COPY --from=ghcr.io/projectbluefin/common:latest /system_files /oci/common
COPY --from=ghcr.io/ublue-os/brew:latest /system_files /oci/brew
```

This stage combines:

- **Local resources** (build scripts, custom files)
- **OCI container resources** from upstream projects
- Resources are copied to **distinct subdirectories** to avoid conflicts

**Stage 2: Final Image**

```dockerfile
FROM ${BASE_IMAGE}                   # default: ghcr.io/ublue-os/bluefin-dx:stable

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/build/10-build.sh
```

The final stage:

- Starts from the base selected by `ARG BASE_IMAGE`
- Mounts the `ctx` stage at `/ctx`
- Runs build scripts with access to all resources

**Accessing OCI Resources in Build Scripts:**

Build scripts can access files from OCI containers:

```bash
#!/usr/bin/env bash
# Example: Copy common desktop config into the image
cp -r /ctx/oci/common/* /usr/share/bluefin/

# Example: Use brew integration files
cp /ctx/oci/brew/*.sh /usr/local/bin/
```

**Renovate Integration:**

- Renovate tracks the container images pinned in `Containerfile` and `Justfile`
- It can update `:latest` tags to SHA digests for reproducibility
- Example: `:latest` → `@sha256:abc123...`

**Reference:** See [Bluefin Contributing Guide](https://docs.projectbluefin.io/contributing/) for architecture diagram

### 10. Image Signing (Jenkins Cosign)

Cosign signing is enabled in the **Jenkins** production pipelines. After
`Push GHCR`, each pipeline captures the published digest and signs
`IMAGE_REPOSITORY@sha256:<digest>` in a `Sign Image` stage gated on `main`.
`build.yml` triggers on pull requests only, so it never publishes or signs.

- **Credentials**: `cosign_key` (Jenkins `Secret file`) and `cosign_pass`
  (Jenkins `Secret text`); the IDs are read by `ci/jenkins/Jenkinsfile.stable`
  and `ci/jenkins/Jenkinsfile.nvidia`. The helper is
  `ci/jenkins/scripts/sign_image.sh`.
- **Public key**: `cosign.pub` is versioned and used for verification:
  `cosign verify --key cosign.pub <image>@<digest>`.
- **Sign by digest, never by tag alone.**
- **Out of scope**: attestations, SBOM, provenance and rechunking are separate
  concerns; do not conflate them with the Cosign signature.
- **NEVER commit `cosign.key`**; it is already in `.gitignore`. Only `cosign.pub`
  may be committed.
- Do **not** move signing or publishing to GitHub Actions.

---

## Critical Rules (Enforced)

1. **ALWAYS** use Conventional Commits format for ALL commits and PR titles
   - Format: `<type>[scope]: <description>`
   - Valid types: `feat:`, `fix:`, `docs:`, `chore:`, `build:`, `ci:`, `refactor:`, `test:`
   - Breaking changes: Add `!` or `BREAKING CHANGE:` in footer
   - See `.github/commit-convention.md` for examples
2. **NEVER** commit `cosign.key` to repository
3. **ALWAYS** disable COPRs after use (`copr_install_isolated` function)
4. **ALWAYS** use `dnf5` exclusively (never `dnf`, `yum`, `rpm-ostree`)
5. **ALWAYS** use `-y` flag for non-interactive installs
6. **NEVER** use `dnf5` in ujust files - only Brewfile/Flatpak shortcuts
7. **ALWAYS** work on a feature branch for development
8. **ALWAYS** merge to `main` through a pull request; Jenkins publishes from `main`
9. **NEVER** push directly to `main`
10. **ALWAYS** confirm with user before deviating from @ublue-os/bluefin patterns
11. **ALWAYS** run shellcheck/YAML validation before committing
12. **ALWAYS** keep the bootc switch URL in `iso/iso.toml` and `iso/iso-nvidia.toml` matching this repository
13. **ALWAYS** follow the numbered script convention: `10-*.sh`, `15-*.sh`, `20-*.sh`, `30-*.sh`, `40-*.sh`
14. **ALWAYS** read the live numbered scripts before creating a new pattern; there are no `.example` files in `build/`
15. **ALWAYS** validate that new Flatpak IDs exist on Flathub before adding
16. **NEVER** modify validation workflows without understanding impact on PR checks
17. **ALWAYS** document Cosign signing accurately: Jenkins signs the published digest by digest; GitHub Actions never publishes nor signs releases
18. **NEVER** make a full local image build a prerequisite for a documentation or script-syntax change - use the light checks

---

## Troubleshooting

| Symptom | Cause | Solution |
|---------|-------|----------|
| Local unit tests won't start | Bats not installed | Install Bats; `just test-unit` prints the install hint |
| Build fails: "package not found" | Typo or unavailable | Check spelling, verify on RPMfusion, add COPR if needed |
| Build fails: "base image not found" | Bad `ARG BASE_IMAGE` or `FROM` | Check the `ARG BASE_IMAGE` default and the `FROM ${BASE_IMAGE}` line in `Containerfile` |
| Build fails: "shellcheck error" | Script syntax error | Run `just lint` (or `shellcheck build/*.sh`) locally, fix errors |
| PR validation fails: Brewfile | Invalid Brewfile syntax | Check Ruby syntax, ensure packages exist |
| PR validation fails: Flatpak | Invalid app ID | Verify app ID exists on <https://flathub.org/> |
| PR validation fails: justfile | Invalid just syntax | Run `just check` locally |
| PR validation fails: Jenkins tests | Broken `ci/jenkins` shell tests | Run `bash ci/jenkins/tests/run-all.sh` locally |
| Changes not in production | Wrong workflow | Verify the Jenkins job and `ci/jenkins/Jenkinsfile.stable`/`ci/jenkins/Jenkinsfile.nvidia` triggers (GitHub Actions never publishes) |
| ISO missing customizations | Wrong bootc URL | Update the bootc switch URL in `iso/iso.toml` and `iso/iso-nvidia.toml` to match this repo |
| COPR packages missing after boot | COPR not disabled | COPRs persist if not disabled - use `copr_install_isolated` |
| ujust commands not working | Wrong install location | Files must be in `custom/ujust/` and copied to the image's ujust directory |
| Flatpaks not installed | Expected behavior | Flatpaks install post-first-boot, not in ISO/container |
| Local build fails | Wrong environment | Must run on bootc-based system or have podman installed |
| Renovate not creating PRs | Configuration or token issue | Check `.github/renovate.json5` syntax and the `permissions`/`GITHUB_TOKEN` in `.github/workflows/renovate.yml` |
| Third-party repo not working | Repo file persists | Remove the repo file at the end of the script (see `build/20-third-party-repos.sh`) |

---

## Common Patterns & Examples

### Pattern 1: Adding Third-Party RPM Repositories

**Use case**: Installing Google Chrome, 1Password, VS Code, etc.

**Example**: See `build/20-third-party-repos.sh`

**Steps**:

1. Add GPG key (if required)
2. Create repo file in `/etc/yum.repos.d/`
3. Install packages with `dnf5 install -y`
4. **CRITICAL**: Remove repo file at end

```bash
# Add repo
cat > /etc/yum.repos.d/google-chrome.repo << 'EOF'
[google-chrome]
name=google-chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF

# Install
dnf5 install -y google-chrome-stable

# Clean up (required!)
rm -f /etc/yum.repos.d/google-chrome.repo
```

### Pattern 2: Using COPR Repositories

**Use case**: Installing packages from Fedora COPR (community repos)

**Example**: See `build/copr-helpers.sh` and `build/30-cosmic-desktop.sh`

**Always use `copr_install_isolated` function**:

```bash
source /ctx/build/copr-helpers.sh

# Install from COPR (isolated - auto-disables after install)
copr_install_isolated "ublue-os/staging" package-name

# Install multiple packages
copr_install_isolated "ryanabx/cosmic-epoch" \
    cosmic-session \
    cosmic-greeter \
    cosmic-comp
```

### Pattern 3: Replacing Desktop Environment

**Use case**: Swap GNOME for KDE, COSMIC, etc.

**Example**: See `build/30-cosmic-desktop.sh` and `build/40-remove-gnome.sh`

**Steps**:

1. Remove old desktop: `dnf5 remove -y gnome-shell ...`
2. Install new desktop: `copr_install_isolated ...`
3. Configure display manager: `systemctl enable ...`
4. Set default session

### Pattern 4: Enabling System Services

**Location**: `build/10-build.sh`

```bash
# Enable service
systemctl enable podman.socket

# Mask unwanted service
systemctl mask unwanted-service

# Set default target
systemctl set-default graphical.target
```

### Pattern 5: Creating Custom ujust Commands

**Location**: `custom/ujust/*.just`

**Example structure**:

```just
# vim: set ft=make :

# Install the default Brewfile
[group('Apps')]
install-default-apps:
    #!/usr/bin/env bash
    set -euo pipefail
    brew bundle --file /usr/share/ublue-os/homebrew/default.Brewfile

# Custom system command
[group('System')]
my-custom-command:
    #!/usr/bin/env bash
    echo "Running custom command..."
    # Your logic here (NO dnf5!)
```

### Pattern 6: Local Testing Workflow

**Light checks first (no build required)**:

```bash
just check                 # Justfile and *.just syntax
just lint                  # shellcheck across *.sh
bats tests/unit/           # static BATS unit tests
git diff --check           # whitespace
```

**Full local cycle (optional, capable machine only)**:

```bash
# 1. Build container image
just build

# 2. Build QCOW2 disk image
just build-qcow2

# 3. Run in VM
just run-vm-qcow2

# Or combine all steps
just build && just build-qcow2 && just run-vm-qcow2
```

**Alternative**: Build ISO for installation testing

```bash
just build
just build-iso
just run-vm-iso
```

### Pattern 7: Pre-commit Validation (Optional)

**Setup pre-commit hooks locally**:

```bash
# Install pre-commit
pip install pre-commit

# Install hooks
pre-commit install

# Run manually
pre-commit run --all-files
```

**Note**: Pre-commit config exists (`.pre-commit-config.yaml`) but is optional. CI validation runs automatically on PRs.

---

## Advanced Topics

### /opt Immutability

Some packages (Chrome, Docker Desktop) write to `/opt`. On Fedora, it's symlinked
to `/var/opt` (mutable). This image already makes `/opt` immutable with the
following `Containerfile` step:

```dockerfile
RUN rm /opt && mkdir /opt
```

### Multi-Architecture

- Local `just` commands support your platform
- Most UBlue images support amd64/arm64
- Add `-arm64` suffix if needed: `bluefin-arm64:stable`
- Cross-platform builds require additional setup

### Custom Build Functions

See `build/copr-helpers.sh` for reusable patterns:

- `copr_install_isolated` - Enable COPR, install packages, disable COPR
- Follow @ublue-os/bluefin conventions exactly

---

## Understanding the Build Process

### Container Build Flow

1. **Base Image** - Pulls the image selected by `ARG BASE_IMAGE` (`FROM ${BASE_IMAGE}`)
2. **Context Stage** - Mounts `build/`, `custom/`, and the `ctx` OCI imports
3. **Build Scripts** - `10-build.sh` runs first and then runs the numbered scripts in order:
   - `10-build.sh` - Always runs first (copies custom files, installs packages)
   - `15-*.sh`, `20-*.sh`, `30-*.sh`, `40-*.sh` - Auto-run in numerical order
4. **Container Lint** - Validates the final image with `bootc container lint --fatal-warnings`
5. **Publish to Registry** - Jenkins pushes to GitHub Container Registry (ghcr.io); GitHub Actions does not publish

**Dual-Variant Build**: The Containerfile accepts `--build-arg BASE_IMAGE=<url>` to override the base image. Two Jenkins pipelines (`ci/jenkins/Jenkinsfile.stable` and `ci/jenkins/Jenkinsfile.nvidia`) build with different base images and publish to separate GHCR packages.

### What Gets Included in the Image

**Build-time (baked into image)**:

- System packages from `dnf5 install`
- Enabled systemd services
- Custom files copied from `/ctx/custom/` to standard locations:
  - Brewfiles → `/usr/share/ublue-os/homebrew/`
  - ujust files → `/usr/share/ublue-os/just/60-custom.just`
  - Flatpak preinstall → `/etc/flatpak/preinstall.d/`

**Runtime (installed after deployment)**:

- Homebrew packages (user runs `ujust install-*`)
- Flatpak applications (installed on first boot, requires internet)

### Local vs CI Builds

**Local builds** (with `just build`):

- Uses your local podman
- Faster for testing
- No signing
- No automatic push to registry

**CI builds** (GitHub Actions):

- Uses GitHub runners
- Runs on pull requests to `main` (PR check only)
- Includes light validation (shellcheck, BATS, Brewfile, Flatpak, justfiles, Renovate, Jenkins tests)
- Never publishes or signs in PR-check mode (signing and publication are Jenkins-only)

**Production builds** (Jenkins):

- Uses self-hosted Jenkins pipelines (`ci/jenkins/Jenkinsfile.stable` and `ci/jenkins/Jenkinsfile.nvidia`)
- Handles the official build, GHCR publish, Cosign signing by digest, GitHub release, and n8n notification

### Image Layers and Caching

**Efficient layering**:

- Each `RUN` command creates a new layer
- Layers are cached between builds
- Changes near end of Containerfile = faster rebuilds
- Use `--mount=type=cache` for package managers

**Best practices**:

- Group related `dnf5 install` commands together
- Don't install and remove in same layer
- Clean up in same RUN command as install

---

## Image Tags Reference

**Main branch** (published by Jenkins):

- `stable` - Latest stable release (recommended)
- `stable.20250129` - Datestamped stable release
- `20250129` - Date only

The NVIDIA pipeline publishes the same tag scheme to
`ghcr.io/ericrocha97/bluefin-cosmic-dx-nvidia`, with release tag
`v<date>-nvidia`. PR-check builds (`build.yml`) are never pushed to the registry,
so there are no published `pr-*` or `sha-*` tags. Both Jenkins pipelines sign the
published digest; verify with
`cosign verify --key cosign.pub <image>@<digest>`.

---

## File Modification Priority

When user requests customization, check in this order:

1. **`build/10-build.sh`** (50%) - Build-time packages, services, system configs
2. **`custom/brew/`** (20%) - Runtime CLI tools, dev environments
3. **`custom/ujust/`** (15%) - User convenience commands
4. **`custom/flatpaks/`** (5%) - GUI applications
5. **`Containerfile`** (5%) - Base image, /opt config, advanced builds
   - **Containerfile**: Uses `ARG BASE_IMAGE` to support dual-variant builds. The default is `bluefin-dx:stable` (standard). Pass `--build-arg BASE_IMAGE=ghcr.io/ublue-os/bluefin-dx-nvidia-open:stable-daily` for the NVIDIA variant. Do not remove the ARG.
6. **`Justfile`** (2%) - Image name, build parameters
7. **`iso/*.toml`** (2%) - ISO/disk customization for testing
8. **`.github/workflows/`** (1%) - PR checks, validation triggers and Renovate
9. **`.agents/skills/`** (1%) - Agent Skills and the router table

### Files to AVOID Modifying

**Do NOT modify unless specifically requested or necessary**:

- `.github/renovate.json5` - Renovate configuration (auto-updates)
- `.github/workflows/validate-*.yml` - Validation workflows
- `.gitignore` - Prevents committing secrets
- `build/copr-helpers.sh` - Helper functions (stable patterns)
- `LICENSE` - Repository license
- `cosign.pub` - Public signing key (regenerate if changing keys)

**Modify with extreme caution**:

- `.github/workflows/build.yml` - PR check workflow (non-publishing)
- `.github/workflows/clean.yml` - Image cleanup
- `Justfile` - Local build automation (users rely on these commands)

---

## Debugging Tips

### Local Debugging

**Build failures**:

```bash
# Build with verbose output (optional; a full build is not a required local gate)
podman build --log-level=debug .

# Check build script syntax
just lint

# Inspect the base image interactively
podman run --rm -it ghcr.io/ublue-os/bluefin-dx:stable bash
# Then run your script commands manually
```

**Brewfile issues**:

```bash
# Validate a Brewfile safely (does not evaluate PR-controlled Ruby)
bash build/validate-brewfiles.sh custom/brew

# Do NOT use `brew bundle check --file <untrusted>` - it evaluates the file as Ruby
```

**Just file issues**:

```bash
# Check syntax
just --list

# Check specific file
just --unstable --fmt --check -f custom/ujust/custom-apps.just

# Run specific command with debug
just --verbose install-default-apps
```

### CI Debugging

**Check workflow logs**:

1. Go to Actions tab in GitHub
2. Click on failed workflow run
3. Expand failed step
4. Look for error messages

**Common CI failures**:

- Shellcheck errors: Fix script syntax
- BATS failures: Run `bats tests/unit/` locally
- Brewfile validation: Check package names exist
- Flatpak validation: Verify app IDs on Flathub
- Jenkins shell tests: Run `bash ci/jenkins/tests/run-all.sh`
- Image pull failures: Check the `BASE_IMAGE` value/tag

**Previewing a PR**:

PR checks do not push an image, so there is no `:pr-NUMBER` tag to pull. Use a
local `just build` or the Jenkins-published `:stable` image to test changes.

### Runtime Debugging

**After deployment**:

```bash
# Check system info
bootc status

# Check running services
systemctl list-units --failed

# Check logs
journalctl -b -p err

# Check ujust commands available
ujust --list

# Check Brewfiles location
ls -la /usr/share/ublue-os/homebrew/

# Check Flatpak preinstall
ls -la /etc/flatpak/preinstall.d/
```

**Flatpak debugging**:

```bash
# Check Flatpak remotes
flatpak remotes

# Check installed Flatpaks
flatpak list

# Install Flatpak manually
flatpak install -y flathub org.mozilla.firefox
```

**Homebrew debugging**:

```bash
# Check Homebrew status
brew doctor

# Check Brewfile
cat /usr/share/ublue-os/homebrew/default.Brewfile

# Install manually
brew install package-name
```

---

## Resources & Documentation

- **Agent Skills**: `.agents/skills/README.md` and the routing table in `.agents/skills/finpilot-router/SKILL.md`
- **Jenkins setup**: `docs/jenkins/README.md`
- **Bluefin patterns**: <https://github.com/ublue-os/bluefin>
- **bootc documentation**: <https://github.com/containers/bootc>
- **Conventional Commits**: <https://www.conventionalcommits.org/>
- **RPMfusion packages**: <https://mirrors.rpmfusion.org/>
- **Flatpak IDs**: <https://flathub.org/>
- **Homebrew**: <https://brew.sh/>
- **Universal Blue**: <https://universal-blue.org/>
- **Renovate**: <https://docs.renovatebot.com/>
- **GitHub Actions**: <https://docs.github.com/en/actions>
- **Podman**: <https://podman.io/>
- **Justfile**: <https://just.systems/>

---

## Other Rules that are Important to the Maintainers

- Ensure that [conventional commits](https://www.conventionalcommits.org/en/v1.0.0/#specification) are used and enforced for every commit and pull request title.
- Always be surgical with the least amount of code, the project strives to be easy to maintain.

## Attribution Requirements

AI agents must disclose what tool and model they are using in the "Assisted-by" commit footer:

```text
Assisted-by: [Model Name] via [Tool Name]
```

Example:

```text
Assisted-by: Claude 3.5 Sonnet via GitHub Copilot
```

---

**Last Updated**: 2026-09-20

**Template Version**: bluefin-cosmic-dx (Dual-build: standard + NVIDIA variants)

**Maintainer**: ericrocha97 (downstream `bluefin-cosmic-dx` fork)
