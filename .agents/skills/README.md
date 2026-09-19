# bluefin-cosmic-dx Skills

## About

This directory contains discoverable Agent Skills for the `bluefin-cosmic-dx`
bootc image repository. Each skill lives in a lowercase directory with a
required `SKILL.md` file whose frontmatter tells compatible agents when to load
it.

The skills are adapted from
[`projectbluefin/finpilot`](https://github.com/projectbluefin/finpilot) to match
this repository: a COSMIC-only custom image based on **Bluefin DX**, built and
published by **Jenkins** for the standard and NVIDIA variants, with **cosign
signing disabled** in this scope.

## Skill Index

| Skill | What it covers |
|---|---|
| [`finpilot-router`](finpilot-router/SKILL.md) | The task routing table: which skill covers what, and the standard sequence. Load when unsure. |
| [`finpilot-overview`](finpilot-overview/SKILL.md) | Repository architecture and file layout. Start here for orientation. |
| [`finpilot-onboarding`](finpilot-onboarding/SKILL.md) | Bootstrap a new fork: rename the identity, enable Actions, first green build, raptor section, branch protection. |
| [`finpilot-templates`](finpilot-templates/SKILL.md) | Image identity ARGs, rename locations, `image-info.json`, and AGENTS.md update rules. Signing stays disabled. |
| [`finpilot-packages`](finpilot-packages/SKILL.md) | Decision tree: where to add packages (`dnf5`, Homebrew Brewfiles, Flatpak preinstall). |
| [`finpilot-custom`](finpilot-custom/SKILL.md) | Runtime layer: Brewfiles, Flatpaks, ujust, `rtk`/`topgrade`, and validation. |
| [`finpilot-build`](finpilot-build/SKILL.md) | `Containerfile`, `Justfile`, `build/*.sh`, `BASE_IMAGE`, lint, and advanced topics. |
| [`finpilot-ci`](finpilot-ci/SKILL.md) | Jenkins pipelines, GitHub Actions PR checks, Renovate, and workflow pins. |
| [`finpilot-maintain`](finpilot-maintain/SKILL.md) | Ongoing work: Renovate PRs, README raptor updates, local test loops. |
| [`finpilot-troubleshooting`](finpilot-troubleshooting/SKILL.md) | Symptom → cause → fix tables for build, CI, and runtime issues. |
| [`finpilot-pr-checklist`](finpilot-pr-checklist/SKILL.md) | Pre-commit and per-change-type validation checklists. |
| [`finpilot-examples`](finpilot-examples/SKILL.md) | Example scripts and the `.example` → `.sh` activation pattern. |
| [`skill-improvement`](skill-improvement/SKILL.md) | Capture durable, repository-specific operational learning. |

Looking for "I need to… → which skill?" — that table lives in
[`finpilot-router`](finpilot-router/SKILL.md), its single canonical home.

## How to Extend Skills

When adding a new skill:

1. **Create a lowercase, hyphenated directory** under `.agents/skills/`
2. **Add `SKILL.md`** with `name` and `description` frontmatter; `name` must match the directory
3. **Describe when to use the skill** precisely so agents can select it automatically
4. **Include the standard sections**: When to Use, When NOT to Use, Core Process, Common Rationalizations, Red Flags, Verification
5. **Add the skill to this README** and to the routing table in `finpilot-router/SKILL.md`
6. **Keep `SKILL.md` focused** — split deep sub-topics into sibling `.md` files in the same directory and link them from `SKILL.md` (relative links, e.g. `[AGENT-BRIEF.md](AGENT-BRIEF.md)`)

## References

- [Agent Skills specification](https://agentskills.io/specification)
- [Adding agent skills for GitHub Copilot](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/add-skills)
- [`AGENTS.md`](../../AGENTS.md) — high-level copilot instructions and mandatory gates
- [`.github/copilot-instructions.md`](../../.github/copilot-instructions.md) — repository pointer to AGENTS.md
