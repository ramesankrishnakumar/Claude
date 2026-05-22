# Forge — Ship Mode

> **When to read this file.** Read at the moment Ship mode is entered. Also read `phases/_shared.md`.

Commit changes and create a pull request.

## Prerequisites

- READ `~/.claude/skills/commit-and-create-pr/SKILL.md` before executing.
- Reads `~/.claude/forge-config.json` `identity` when present.

## Workflow

1. Read `.forge/{slug}/issues.json` for issue numbers (written by Issues mode / YOLO §5.3).
   - `status: "complete"` → use `#N` refs in commit/PR title.
   - `status: "in_progress"` → poll at 5s, 15s, 30s; then `ISSUE-PENDING`.
   - `status: "failed"` → `ISSUE-PENDING`; surface error in summary.
   - Missing file → ask: "Issue number for this PR? (#123 or 'none')"

2. **Test/lint gate** (with `Last Verified` short-circuit per existing STATUS.md rules). Discover commands from CLAUDE.md → README → package manifests. Respect `preferences.verification`.

3. **Optional pre-ship code review** (same shape as Build Step 9 when skipped earlier).

4. Invoke `commit-and-create-pr` with issue ref and forge context (plan.md, DECISIONS.md, design doc links, test plan from checklist).

5. Print `CI: not watched — check {pr-url}/checks`.

6. Record PR URL in STATUS.md.

7. End-of-Ship summary (tests, lint, review, CI link).

8. Phase → `Review`; AUQ approve / revise.
