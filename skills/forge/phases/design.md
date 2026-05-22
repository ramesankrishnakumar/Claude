# Forge — Design Mode

> **When to read this file.** Read at the moment Design mode is entered. Also read `phases/_shared.md` for STATUS.md format.

Write a design doc, optionally push to Google Docs.

## Prerequisites

- **Composed skill (primary)**: READ `~/.claude/skills/design-doc/SKILL.md` before executing this mode.
- **Composed skill (optional)**: `~/.claude/skills/google-docs/SKILL.md` — only READ if the user wants to push to Google Docs.

## Workflow

> **Design is opt-in from the menu.** There is no auto-skip-when-Simple gate. The user decides whether the change warrants a design doc. Plan mode already skips the alternatives section when only one approach is reasonable, which handles the "obvious" case at Plan time.

1. Before invoking the design-doc skill, read existing forge context:
   - `.forge/{slug}/plan.md` — for problem statement, approach, and key decisions.
   - `.forge/{slug}/DECISIONS.md` — for rationale behind key choices (Locked decisions + Claude's discretion buckets; Deferred ideas omitted as out of scope for the doc).
   - `.forge/{slug}/QUESTIONS.md` — check for any open (unresolved) questions; surface them now if any remain.
   - `.forge/{slug}/STATUS.md` — pull the `Goal` and `What matters` from the Context section.

2. Invoke the `design-doc` skill, passing the plan context as the feature background so it doesn't re-ask questions already answered in Plan. Pass:
   - `plan.md` (problem, approach, key decisions).
   - The Locked + Claude's-discretion decision rows.
   - `Goal` + `What matters` (the user's own framing).

   **Weight the section emphasis based on topics in `What matters`:**
   - If `What matters` flagged layout / microcopy → emphasize the UX/screen-state sections.
   - If it flagged cost / scaling → emphasize the architecture/scaling sections.
   - If it flagged rollout / cohort → emphasize the launch-phasing section.

   The composed `design-doc` skill is repo-aware. If the active repo has ADRs, paved paths, or pattern docs, the design-doc skill itself knows how to find them — forge does not prescribe repo-specific paths.

3. **Mermaid where structure has a known shape.** Prompt the design-doc skill to embed Mermaid diagrams when the architecture has a known shape — e.g., a sequence flow with 3+ actors, a multi-repo dependency graph, or a layered architecture. Don't draw a diagram for a single decision. Per the Visuals section in `SKILL.md`, **Mermaid** diagrams live in the design-doc file only — never in chat.

4. After the design doc is written and the user is satisfied with it, ask via `AskUserQuestion` (header `"Push to Docs"`, options: `Yes, push to Google Docs (Recommended)` / `No, keep local only`). Per the contract in `_shared.md`.

   - **Yes**: READ `~/.claude/skills/google-docs/SKILL.md`. Follow its workflow to create a Google Doc from the markdown file. Record the Google Doc URL in STATUS.md.
   - **No**: Skip.

5. Record the local doc path (and Google Doc URL if created) in STATUS.md Context section.
6. Tell the user: "Design doc ready at {path}." (And "Google Doc: {url}" if created.)

   **Visualize-offer (optional).** Offer: *"Open the design doc as HTML?"* via `AskUserQuestion` (header `"Visualize"`, options: `Yes, open it (Recommended)` / `Skip`). If accepted, READ `phases/_visualize.md` and follow it (source → `docs/{slug}-design.md`, output → `docs/{slug}-design.html`).

7. Update STATUS.md: Phase → `Review`.
