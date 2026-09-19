---
name: finpilot-custom
description: >-
  Runtime layer of bluefin-cosmic-dx: Brewfiles, Flatpaks, and ujust commands —
  syntax, placement, and safe validation. Use when modifying custom/ or
  explaining the runtime layer to contributors.
---

# bluefin-cosmic-dx Runtime Layer

## When to Use

- Adding or editing Homebrew Brewfiles (`custom/brew/*.Brewfile`)
- Adding or editing Flatpak preinstall files (`custom/flatpaks/*.preinstall`)
- Adding or editing ujust command files (`custom/ujust/*.just`)
- Explaining the runtime vs build-time distinction to contributors
- Debugging why a Brewfile or Flatpak did not install as expected

## When NOT to Use

- Build script changes — use `finpilot-build`
- CI workflow or Jenkins changes — use `finpilot-ci`
- Deciding where a package belongs — use `finpilot-packages`

## Core Process

1. **Identify the runtime need**: CLI tool, GUI app, or user convenience command
2. **Choose the right runtime file**: Brewfile (CLI), Flatpak (GUI), or ujust (shortcut)
3. **Apply the correct syntax** for that file type
4. **Validate lightly** — never evaluate a PR-controlled file as code
5. **Update the README raptor section** when the shipped runtime set changes (`finpilot-maintain`)

## Build-Time vs Runtime

| Layer | Where it lives | When it lands | Examples |
| --- | --- | --- | --- |
| Build-time | `build/*.sh` via `dnf5` | Baked into the image | System packages, services, COSMIC desktop |
| Runtime | `custom/*` | After first boot, by the user | `rtk`, `topgrade`, Zen Browser Flatpak |

Runtime customizations keep the image lean and let users add tools without a
rebuild. Do not move a runtime CLI or GUI tool into a build script just to make
it available offline — see `finpilot-packages`.

## Brewfiles: `custom/brew/*.Brewfile`

Brewfiles use Ruby syntax. They declare Homebrew packages that users install
after deployment. `build/10-build.sh` copies every `*.Brewfile` from
`custom/brew/` into `/usr/share/ublue-os/homebrew/` during the build.

The shipped `custom/brew/default.Brewfile` contains `rtk` (a CLI proxy that
minimizes LLM token consumption) and `topgrade` (upgrades everything with one
command).

### File Locations

| File | Purpose |
| --- | --- |
| `custom/brew/default.Brewfile` | Shipped runtime CLI tools (`rtk`, `topgrade`) |
| Custom `*.Brewfile` | None ship today; future optional files (e.g. a `development.Brewfile` or `fonts.Brewfile`) only if a real need arises |

### Syntax

```ruby
# CLI tools
brew "bat"        # Better cat with syntax highlighting
brew "eza"        # Modern replacement for ls
brew "ripgrep"    # Faster grep

# Taps (third-party repositories)
tap "homebrew/cask"

# Casks (GUI applications)
cask "visual-studio-code"
```

Keep declarations literal. The validator below rejects interpolation and extra
arguments instead of executing them.

### How Users Invoke Them

Each Brewfile ships with a matching shortcut in `custom/ujust/`. The shipped
default is:

```bash
# Install every tool in default.Brewfile (rtk, topgrade)
ujust install-default-apps
```

### Validation

Never validate a PR-controlled Brewfile by evaluating it as Ruby. The
repository ships a fail-closed validator that only greps literal declarations
and passes names to `brew info` as data:

```bash
just validate-brewfiles
# or
bash build/validate-brewfiles.sh custom/brew
```

`build/validate-brewfiles.sh` rejects interpolated names, trailing arguments,
and non-literal tap lines before any Ruby evaluator sees them. It is wired into
`.github/workflows/validate-brewfiles.yml` and `.pre-commit-config.yaml`.
Do **not** substitute `brew bundle check --file` on an untrusted Brewfile: that
would execute PR-controlled Ruby. `brew info` requires `brew` in the
environment; when it is unavailable, record that the check could not run rather
than skipping silently.

## Flatpaks: `custom/flatpaks/*.preinstall`

Flatpak preinstall files use INI format. `build/10-build.sh` copies them to
`/etc/flatpak/preinstall.d/` during the build; they are installed on **first
boot**, after network setup.

### File Locations

| File | Purpose |
| --- | --- |
| `custom/flatpaks/default.preinstall` | Shipped GUI app (Zen Browser) |
| Custom `*.preinstall` | Create as needed |

### Syntax

```ini
[Flatpak Preinstall app.zen_browser.zen]
Branch=stable
```

### Key Rules

- **Post-first-boot only**: Flatpaks are not baked into the container or ISO;
  they need a network connection on first boot.
- **Always specify `Branch=stable`** (or another valid branch).
- **Verify the app ID on Flathub** (https://flathub.org/) before adding it.
- **Validation**: `.github/workflows/validate-flatpaks.yml` checks app IDs
  against Flathub.

## ujust: `custom/ujust/*.just`

ujust recipes are user convenience commands. `build/10-build.sh` concatenates
every `.just` file in `custom/ujust/` into
`/usr/share/ublue-os/just/60-custom.just` (sorted, one consolidated file).

### Critical Rule: No System Package Managers

ujust is a user-level shortcut layer. It must only call user tools such as
`brew bundle`, `flatpak`, or plain shell — never a system package manager
(`dnf5`, `dnf`, `yum`, or `rpm-ostree`). Anything that changes the image
belongs in a build script.

```just
# vim: set ft=make :

[group('Apps')]
install-default-apps:
    #!/usr/bin/env bash
    set -euo pipefail
    brew bundle --file /usr/share/ublue-os/homebrew/default.Brewfile

[group('System')]
my-custom-command:
    #!/usr/bin/env bash
    echo "Running custom command..."
    # Your logic here — never install system packages
```

### Syntax Rules

- Use a bash shebang (`#!/usr/bin/env bash`) and `set -euo pipefail`
- Use `[group('Category')]` to organize `ujust --list`
- Use descriptive, kebab-case recipe names (`install-`, `configure-`, `setup-`)
- Recipes run with user privileges; use `sudo`/`pkexec` only when required

### Validation

```bash
just check   # just --unstable --fmt --check for every .just file and the Justfile
```

`.github/workflows/validate-justfiles.yml` runs the same format check on PRs
that touch `custom/ujust/**` or the `Justfile`.

## Validation Workflows by File Type

| File Type | Workflow | What it checks |
| --- | --- | --- |
| `*.Brewfile` | `validate-brewfiles.yml` | Literal names + existence via the safe validator |
| `*.preinstall` | `validate-flatpaks.yml` | App ID existence on Flathub |
| ujust files | `validate-justfiles.yml` | Format/syntax via `just --unstable --fmt --check` |

## Common Rationalizations

| Rationalization | Reality |
| --- | --- |
| "I'll install this system package from a ujust recipe for convenience." | Never. ujust runs as the user; image changes belong in a build script. |
| "Flatpaks should be baked into the container so they work offline." | Flatpaks install after first boot on purpose, keeping the image small and independently updatable. |
| "I'll inline the Brewfile in the recipe instead of a separate file." | Separate `*.Brewfile` files are what `10-build.sh` copies and what `ujust install-default-apps` reads. |
| "I'll validate the Brewfile with `brew bundle check --file`." | That evaluates untrusted Ruby. Use `build/validate-brewfiles.sh` / `just validate-brewfiles`. |
| "The recipe works without a shebang if it is just one command." | Always declare the shell explicitly for a deterministic execution context. |

## Red Flags

- A package manager (`dnf5`, `dnf`, `yum`, `rpm-ostree`) used inside a ujust recipe
- A Flatpak entry without `Branch=stable`
- A `*.Brewfile` with no matching ujust shortcut
- An app ID in a preinstall file that was not verified on Flathub
- Validating a Brewfile with `brew bundle check` instead of the safe validator
- A new ujust file that only re-implements an existing build script

## Verification

- [ ] Does each `*.Brewfile` have a matching ujust shortcut?
- [ ] Do all Flatpak entries specify `Branch=stable`?
- [ ] Was each app ID verified on Flathub?
- [ ] Did `just check` pass for the ujust files?
- [ ] Did `just validate-brewfiles` (or `bash build/validate-brewfiles.sh custom/brew`) pass without evaluating Ruby?
- [ ] Does no ujust recipe install system packages?
- [ ] Is the build-time vs runtime boundary still respected?
