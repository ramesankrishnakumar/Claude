# Forge — Init Mode

> **When to read this file.** Read when the user runs `forge init`, voices a config-preference change, OR when no `~/.claude/forge-config.json` exists at the start of any forge invocation.

One-time setup in `~/.claude/forge-config.json` for GitHub identity, default repo for issues, and preferences.

## When init runs

- **User-typed**: `forge init` at any time.
- **Auto-prompt**: on first forge invocation if config is missing. Offer via `AskUserQuestion` (header `"Forge init"`, options: `Run forge init (~15s) (Recommended)` / `Skip and use defaults`). Never auto-runs without opt-in.

## Schema

```json
{
  "identity": {
    "github_login": "octocat",
    "email": "you@example.com"
  },
  "issues": {
    "default_repo": "owner/repo"
  },
  "preferences": {
    "audience": "non-technical",
    "verification": "strict",
    "code_review": "advisory",
    "plan_quality_gate": "warn"
  }
}
```

| Block | Key | Purpose |
|---|---|---|
| `identity` | `github_login` | GitHub username for `gh` and issue assignee |
| `identity` | `email` | Git / commit context |
| `preferences` | `audience` | `non-technical` \| `technical` |
| `preferences` | `verification` | `lenient` \| `strict` |
| `preferences` | `code_review` | `off` \| `advisory` \| `block_critical` |
| `preferences` | `plan_quality_gate` | locked at `warn` |

## Workflow

### Step 1 — Pre-fill

**Identity:**
- `github_login` — from `gh auth status` (github.com). Fallback: local-part of `git config user.email`.
- `email` — `git config user.email`.

Hard-fail if both `github_login` and `email` cannot be resolved. Ask user to run `gh auth login` and `git config user.email`.

**Issues:**
- `default_repo` — from `git remote get-url origin` → `owner/repo` (strip `.git`, handle `git@github.com:owner/repo` and `https://github.com/owner/repo`).

**Preferences** (silent defaults): `audience=non-technical`, `verification=strict`, `code_review=advisory`, `plan_quality_gate=warn`.

If config exists, merge with existing values.

### Step 2 — Render once

Show: `github_login`, `email`, `default_repo`. Editable keys: `login`, `email`, `repo`.

Prompt: *"Type `save` to write as-is, or `key=value` (e.g. `repo=myorg/myrepo`)."*

### Step 3 — Parse response

- `save` / `ok` / `yes` / `y` → accept pre-fill.
- `key=value` pairs: `login`, `email`, `repo` (+ hidden preference keys for power users).

### Step 4 — Write file

Write full schema to `~/.claude/forge-config.json`. Confirm path in chat.

### Step 5 — Reachability

```bash
gh api user -q .login
```

- Success: *"GitHub reachable ✓"*
- Failure: *"Couldn't reach GitHub — config saved; run `gh auth login` when online."*

Init does not modify `.forge/{slug}/`. Return to dispatcher.

## Per-slug overrides

In STATUS.md frontmatter:

```yaml
---
overrides:
  code_review: block_critical
---
```

## What init does NOT do

- Does not create `.forge/{slug}/`.
- Does not configure MCP servers.
- Does not set per-slug Goal / What matters (forge-create only).
