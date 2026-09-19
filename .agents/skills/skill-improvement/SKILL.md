---
name: skill-improvement
description: Record durable bluefin-cosmic-dx-specific learning after discovering a command, convention, workaround, or failure mode.
---

# Skill Improvement

## When to Use

- A task reveals a bluefin-cosmic-dx-specific command, constraint, workaround,
  or failure mode.
- Updating a local skill, the task router, or agent instructions.
- Preparing a pull request or handoff after nontrivial work.

## When NOT to Use

- The finding is a factory-wide rule owned by `projectbluefin/common`.
- The information is transient task state, a backlog item, or a resolved PR.
- The work contains no reusable learning.

## Core Process

1. Decide whether the finding is specific to this repository or factory-wide.
2. Update the closest relevant local skill with the timeless operating rule and
   its validation command.
3. Route factory-wide learning to `projectbluefin/common`; never edit
   `ublue-os/*`.
4. Validate the updated guidance in the same change as the implementation.

Do not create changelogs, session logs, task notes, or "append here" documents.
They become stale and are not part of the repository knowledge base. Keep
temporary state in the agent session workspace and record only verified,
reusable guidance in a skill.

When adding or renaming a skill, follow the README rules in `.agents/skills/`
and update the routing table in `finpilot-router/SKILL.md` in the same change.
Frontmatter `name` must match the directory name.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "The lesson is obvious." | If it changed how this task was performed, future agents need it. |
| "I will document it later." | The implementation context is most accurate in the same PR. |
| "A session note is quicker." | Session notes rot; skills are the durable operating model. |
| "The router table can wait." | A new skill missing from the router is invisible to agents. Update both. |

## Red Flags

- A nontrivial task ends without a relevant skill update.
- A skill contains session history, an issue list, or unresolved task state.
- A repository-specific lesson is written only in a PR comment or commit message.
- A new skill is added without updating `.agents/skills/README.md` and the router.
- A local skill contradicts the actual files, commands, or policy in this repo.

## Verification

- Confirm the learning is specific to this repository rather than a factory-wide rule.
- Update the relevant skill with the command, boundary, and validation evidence.
- Route factory-wide learning to `projectbluefin/common`; never edit
  `ublue-os/*`.
- Confirm `name` frontmatter matches the directory and the router lists the skill.
