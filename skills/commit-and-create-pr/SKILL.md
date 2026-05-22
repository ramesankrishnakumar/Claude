---
name: commit-and-create-pr
description: >
  Create a feature branch, commit, push, and open a GitHub PR with conventional
  commits (≤72-char title). Optional GitHub issue ref in the message. Handles
  branch naming, base-branch detection, and stash/restore of unrelated changes.
  Trigger when user says: commit, create PR, ship, branch and PR, open a pull
  request, push and open PR, or mentions an issue number with intent to ship.
user-invocable: true
---

# Commit and Create PR

**Goal:** Create a feature branch, commit relevant changes, and open a GitHub PR with `gh`.

> **Scope:** Plumbing only — branch, commit, push, PR. Does **NOT** run tests. Forge Ship runs the test gate first.

## Usage

`/commit-and-create-pr` or `/commit-and-create-pr #42` or `/commit-and-create-pr none`

If no issue ref is provided, ask whether to include `#N` in the commit/PR title or use `none`.

---

## Steps

### 1. Issue ref and scope

- **Issue ref:** `#42`, `42`, or `none`. Include in title as `fix: #42 summary` when present.
- **Scope:** Stage only files for this change; stash unrelated work and restore at end.

### 2. Base branch and feature branch

- Detect default branch: `git remote show origin | grep 'HEAD branch'`.
- Update base from remote; create feature branch from base.
- Short descriptive branch name (issue number not required in branch name).

### 3. Commit

- **Format:** `fix:` or `feat:` + optional `#N` + imperative summary. First line ≤ 72 characters.

**Examples:**
- `fix: populate user id on conversation endpoint`
- `fix: #42 retry backoff in payment webhook`
- `feat: add structured logging to webhook module`

### 4. Push and PR

- `gh pr create` with title matching commit style; body: context, changes, verification steps.

### 5. Update PR body after follow-up pushes

- If branch changes after PR open, `gh pr edit` so description matches final commits.

### 6. Cleanup

- `git stash pop` if a stash was created.

---

## Checklist

- [ ] Default branch detected dynamically
- [ ] Feature branch from up-to-date base
- [ ] Only scoped files committed
- [ ] Commit/PR title ≤ 72 chars, conventional format
- [ ] Stash restored if used
