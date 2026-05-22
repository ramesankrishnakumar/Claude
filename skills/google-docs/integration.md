# Google Docs Integration for Skills

This file provides instructions for other skills that produce document artifacts.

## When to Create a Google Doc

**Automatic (no confirmation needed):**
- User explicitly mentions "Google Doc", "Google Docs", "create in Docs", "save to Docs", etc.

**With confirmation:**
- After displaying the report locally, ask: "Would you like me to create this as a Google Doc?"

## How to Create the Doc

After saving the local Markdown file, use:

```bash
~/.claude/skills/google-docs/scripts/create_from_markdown.sh "Document Title" --file /path/to/report.md
```

Or pipe content directly:

```bash
cat /path/to/report.md | ~/.claude/skills/google-docs/scripts/create_from_markdown.sh "Document Title"
```

## Prerequisites Check

Before creating a Google Doc, verify `gws` is available and authenticated:

```bash
if ! command -v gws &>/dev/null; then
  echo "Google Docs requires the gws CLI."
elif ! gws docs documents get --params '{"documentId":"test"}' 2>/dev/null | grep -q '"error"'; then
  echo "Auth may need refresh. Run: gcloud auth login"
fi
```

## Title Conventions

Use the same naming convention as the local file, but formatted for display:

| Local filename | Google Doc title |
|----------------|------------------|
| `feature-tech-spec-2026-02-27.md` | Feature Tech Spec - 2026-02-27 |
| `auth-flow-report-2026-02-27.md` | Auth Flow Report - 2026-02-27 |
| `logging-plan-2026-02-27.md` | Logging Plan - 2026-02-27 |

## Output

After creating the doc, display:

```
Google Doc created: [Title]
  URL: https://docs.google.com/document/d/DOC_ID/edit
```
