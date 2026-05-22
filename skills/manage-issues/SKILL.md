---
name: manage-issues
description: >
  Create, link, and list GitHub issues for the configured default repo using gh.
  Reads ~/.claude/forge-config.json for identity and issues.default_repo.
  Trigger when user says: create an issue, file a ticket, link issue #123,
  manage-issues, or forge Issues mode needs issue creation.
user-invocable: true
---

# Manage GitHub Issues

**Config:** Read `~/.claude/forge-config.json` before any operation.

Hard-fail if missing or incomplete (`identity` or `issues.default_repo`):

> *"`manage-issues` requires forge config. Run `forge init` first, then retry."*

| Config key | Use |
|---|---|
| `$CONFIG.identity.github_login` | `--assignee` when creating issues |
| `$CONFIG.identity.email` | Context only |
| `$CONFIG.issues.default_repo` | `owner/repo` for all `gh` calls |

---

## Mode: Create

From a description or from `.forge/{slug}/plan.md`:

1. Propose a breakdown (title + body summary per issue). Wait for user approval unless YOLO sub-agent contract applies.
2. For each approved item:

```bash
gh issue create --repo "$CONFIG.issues.default_repo" \
  --title "TITLE" \
  --body "BODY" \
  --assignee "$CONFIG.identity.github_login"
```

3. Collect `number`, `url`, `title` for each created issue.

---

## Mode: Link

User provides `#123`, `123`, or full issue URLs. Verify with:

```bash
gh issue view 123 --repo "$CONFIG.issues.default_repo" --json number,title,url
```

---

## Output contract (forge)

Write `.forge/{slug}/issues.json`:

```json
{
  "status": "complete",
  "tickets": [{"number": 42, "url": "https://github.com/owner/repo/issues/42", "title": "..."}],
  "started_at": "ISO-8601",
  "finished_at": "ISO-8601"
}
```

On failure: `"status": "failed"` and `"error": "message"`.

---

## Help

```
/manage-issues <description>     Create issues from description
/manage-issues link #1 #2       Link existing issues
/manage-issues help             Show this help
```

Configuration: `~/.claude/forge-config.json` — set via `forge init`.
