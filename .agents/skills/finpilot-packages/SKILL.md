---
name: finpilot-packages
description: >-
  Decision tree for where to add packages in bluefin-cosmic-dx. Maps a request
  to the correct file and install method: build-time dnf5, isolated COPR,
  runtime Brewfile, or runtime Flatpak. Use when adding a package or tool.
---

# bluefin-cosmic-dx Package Decision Tree

## When to Use

- A user or agent asks "how do I add package X?"
- You need to decide whether a package belongs in build-time or runtime
- Reviewing a PR that adds packages and verifying they are in the right place
- Creating new build scripts, Brewfiles, or Flatpak preinstall files

## When NOT to Use

- You already know the target file and install method — go edit it directly
- You are debugging why a package fails to install — use `finpilot-troubleshooting`

## Core Process

1. **Identify the package type** (system utility, CLI tool, GUI app, service)
2. **Use the decision table below** to map it to the correct path
3. **Apply the installation pattern** for that path
4. **Consider scope**: doc/skill changes (no CI impact) vs build or runtime
   changes (trigger validation in CI)

## Decision Table

| Request | Action | Location |
| --- | --- | --- |
| Add a system package | `dnf5 install -y pkg` | `build/10-build.sh` |
| Add a COPR package | `copr_install_isolated "owner/repo" pkg` | `build/10-build.sh` or a numbered script |
| Add a third-party repo package | Enable repo → `dnf5 install -y` → remove repo file | `build/20-third-party-repos.sh` (or a new `20-*.sh`) |
| Add a CLI tool (runtime) | `brew "pkg"` | `custom/brew/default.Brewfile` |
| Add a font | `brew "font-xyz"` | a `custom/brew/*.Brewfile` |
| Add a GUI app | `[Flatpak Preinstall org.app.id]` | `custom/flatpaks/default.preinstall` |
| Add a user command | Create a ujust recipe (no `dnf5`) | `custom/ujust/*.just` |
| Enable a systemd service | `systemctl enable service.name` | `build/10-build.sh` |
| Change the desktop session | Remove/install packages, enable greeter | `build/30-*.sh`, `build/40-*.sh` |
| Switch the base image | Update the `BASE_IMAGE` default or pass `--build-arg` | `Containerfile`, `Justfile`, Jenkins |
| Add OCI context files | Add/modify `COPY --from=` in the ctx stage | `Containerfile` |
| Add an NVIDIA package | Do **not** add a variant script; extend the shared build and rely on the NVIDIA base/pipeline | `Containerfile` / `ci/jenkins/Jenkinsfile.nvidia` |

## Build-Time: `build/10-build.sh`

System packages are installed at build time and baked into the image.

```bash
# In build/10-build.sh
dnf5 install -y earlyoom ffmpegthumbnailer
systemctl enable podman.socket
```

**When to use:**

- System utilities, daemons, and services
- Dependencies required by other build-time steps
- Packages that must exist before runtime customizations

**Rules:**

- Always `dnf5` (never `dnf`, `yum`, or `rpm-ostree`)
- Always `-y` for non-interactive installs
- Group related installs for layer caching
- Verify installs with `verify_package` / `verify_packages` from
  `build/copr-helpers.sh`

## COPR: `copr_install_isolated`

Community repositories must be isolated so they never persist into the image.

```bash
# shellcheck source=/dev/null
source /ctx/build/copr-helpers.sh
copr_install_isolated "ryanabx/cosmic-epoch" cosmic-session cosmic-comp
```

`copr_install_isolated` enables the COPR, disables it again, then installs
with `--enablerepo=` so the repo is never left active. **Never leave a COPR
enabled after install.**

## Third-Party Repos: `build/20-*.sh`

For vendors like Microsoft (VS Code) or Warp Terminal, follow
`build/20-third-party-repos.sh`:

1. Add the vendor GPG key if required
2. Create the repo file in `/etc/yum.repos.d/`
3. `dnf5 install -y` the package(s)
4. **Remove the repo file at the end of the script**

Repos added at build time are not available at runtime, so the cleanup step is
mandatory.

## Runtime Brew: `custom/brew/*.Brewfile`

Homebrew is for CLI tools, installed by users after first boot. The image ships
`custom/brew/default.Brewfile` (`rtk` and `topgrade`) and exposes it through
`ujust install-default-apps`. Brewfiles are copied to
`/usr/share/ublue-os/homebrew/` during the build.

Brewfile syntax, the safe validator, and the copy/run flow live in
`finpilot-custom`.

## Runtime Flatpak: `custom/flatpaks/*.preinstall`

Flatpaks are GUI apps installed after first boot (not in the container image).
Files are copied to `/etc/flatpak/preinstall.d/` during the build. Use INI
syntax with `[Flatpak Preinstall org.app.id]` and `Branch=stable`, and verify
the app ID exists on Flathub before adding it. Details in `finpilot-custom`.

## Safe Brewfile Validation

Never validate a PR-controlled Brewfile by evaluating it as Ruby. Use the
fail-closed validator:

```bash
just validate-brewfiles
# or
bash build/validate-brewfiles.sh custom/brew
```

`build/validate-brewfiles.sh` greps for literal `brew`/`cask`/`tap`
declarations and passes names to `brew info` as data. Computed Ruby
(interpolation, extra arguments) is rejected instead of executed. This is the
local equivalent of the upstream validation and is wired into
`.github/workflows/validate-brewfiles.yml` and `.pre-commit-config.yaml`.

## Scope Rules

### Doc and skill tasks (no CI impact)

README, `docs/`, `.agents/skills/`, and `.gitignore` edits trigger no image
build.

### Build and runtime tasks (CI impact)

Which `validate-*.yml` workflow fires for each file type, and how Jenkins fits
in, is documented in the Workflow Map in `finpilot-ci`.

## Common Rationalizations

| Rationalization | Reality |
| --- | --- |
| "I'll put this CLI tool in `build/10-build.sh` so it is always available." | Build-time packages bloat the image. Prefer the runtime Brewfile unless it must exist before first boot. |
| "I'll add a GUI app via `dnf5` so it works offline." | Flatpaks are the standard for GUI apps; they update independently and keep the image lean. |
| "COPR packages are safe to leave enabled." | Enabled COPRs persist and can break updates. Always use `copr_install_isolated`. |
| "I can validate the Brewfile with `brew bundle check` in CI." | That evaluates PR-controlled Ruby. Use `build/validate-brewfiles.sh`. |
| "NVIDIA tools go in a separate variant script." | The NVIDIA variant is the same build with a different `BASE_IMAGE`; do not fork the build logic. |

## Red Flags

- Using `dnf` or `yum` instead of `dnf5`
- Leaving a COPR enabled after install
- Not removing a third-party repo file after install
- Adding GUI apps via `dnf5` instead of Flatpak
- Adding CLI tools to the build when runtime Brew is the right layer
- Validating Brewfiles with `brew bundle check` instead of the safe validator
- Adding system/COPR packages inside `custom/ujust/*.just`
- Duplicating build logic for the NVIDIA variant

## Verification

- [ ] Does the package type match the chosen installation method?
- [ ] For build-time: does it use `dnf5 install -y` and `verify_package`?
- [ ] For COPR: is `copr_install_isolated` used and the repo disabled?
- [ ] For a third-party repo: is the repo file removed at the end of the script?
- [ ] For Flatpak: is the app ID verified on Flathub?
- [ ] For Brewfile: is the name a literal and does the safe validator pass?
- [ ] Does the changed path trigger the correct `validate-*.yml` workflow (see `finpilot-ci`)?
