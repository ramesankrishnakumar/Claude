# Forge — Issues Mode

> **When to read this file.** Read when Issues mode is entered. Also read `phases/_shared.md`.

Create or link GitHub issues for this forge.

## Prerequisites

- READ `~/.claude/skills/manage-issues/SKILL.md` before executing.
- `forge init` must have written `~/.claude/forge-config.json`.

## Workflow

> **Output contract:** writes `.forge/{slug}/issues.json`. Ship reads this file.

1. `AskUserQuestion` (header `"Issues mode"`, options: `Create new issues (Recommended)` / `Link existing issues`).

2. **Link:** Ask for `#123` or URLs. Write `issues.json` with `status: "complete"`. Set STATUS Context `Issues File` path.

3. **Create:**
   a. Read `plan.md` if present.
   b. Propose breakdown (title, summary, size S/M/L). Wait for approval.
   c. Create via `manage-issues` Create mode.
   d. Write `issues.json`; on failure `status: "failed"` + `error`.

4. STATUS Phase → `Review`.
5. `AskUserQuestion` (header `"Issues ready"`, options: `Approve and continue (Recommended)` / `Revise`).
