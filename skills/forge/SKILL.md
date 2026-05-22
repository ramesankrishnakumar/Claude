---
name: forge
description: >
  Lightweight engineering workflow orchestrator. Chains planning, GitHub issues,
  design docs, code implementation, and PR creation into a flexible step-by-step
  pipeline. Use when the user says "forge", "plan and ship a feature", "start a
  new feature workflow", "resume forge", "forge init", or "/forge".
---

# Forge

Forge walks you through an engineering workflow one step at a time — Plan, Issues, Design, Build, Ship — composing skills at each step. Every step is optional. State lives on disk so you can resume across sessions.

---

## Lazy-loading dispatcher

| When to read | File | What's in it |
|---|---|---|
| Always (this file) | `SKILL.md` | Hard rules, config schema, visuals, dispatch table |
| First state-file read or write | `phases/_shared.md` | STATUS.md / QUESTIONS.md / DECISIONS.md formats |
| Every invocation, before menu | `phases/_entry.md` | Detect, create, resume, menu, approve, rewind |
| `yolo` at start or end of message | `phases/yolo.md` | Autonomous plan → issues → build → review → apply → ship |
| `forge init` or missing config | `phases/_init.md` | Identity / GitHub repo / preferences |
| Plan | `phases/plan.md` | Plan mode |
| Issues | `phases/issues.md` | GitHub issues mode |
| Design | `phases/design.md` | design-doc, optional google-docs |
| Build | `phases/build.md` | Implementation + code review |
| Ship | `phases/ship.md` | Tests gate + commit-and-create-pr |
| Visualize offer accepted | `phases/_visualize.md` | plan-to-html HTML view |

**Discipline:** do not preload phase files.

---

## Hard Rules

1. **Stop at each mode.** Exception: YOLO (`phases/yolo.md`) runs end-to-end.
2. **Write to files.** State in `.forge/{slug}/`; design docs in `docs/`.
3. **Flexible order.** Any mode, any order, skip anything.
4. **Resume from disk.** `.forge/{slug}/STATUS.md` is source of truth.
5. **Lazy-load phases.**

---

## Configuration

`~/.claude/forge-config.json` — sections `identity`, `issues`, `preferences`. See `phases/_init.md`.

`yolo` is a per-invocation keyword, not a config preference.

---

## YOLO trigger

Standalone `yolo` at **start or end** of the message (case-insensitive):

- `forge yolo "add retry to webhook handler"`
- `fix button padding yolo`

Dispatches to `phases/yolo.md` (plan → issues → build → review → apply → ship). Hard Rule 1 suspended for the run.

---

## Per-slug context (forge-create)

- **Goal** — one sentence customer outcome.
- **What matters** — constraints and success criteria in the user's words.

Tone: `preferences.audience`. See `phases/_entry.md` Step 2.

---

## Visuals

Mermaid in `plan.md` and design docs only — not in chat. HTML via `phases/_visualize.md` + `plan-to-html`.

---

## Entry flow

1. READ `phases/_entry.md`
2. On mode pick, READ `phases/{mode}.md`
3. On state I/O, READ `phases/_shared.md`
4. On `forge init`, READ `phases/_init.md`
