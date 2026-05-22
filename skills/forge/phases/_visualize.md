# Visualize dispatcher

Lazy-loaded spec for forge's on-demand visualizer. Any phase that wants to offer the human a polished HTML view of an artifact (or an ad-hoc concept) defers here.

This file is loaded **only** when the user explicitly asks to visualize something, or when the agent offers a visualization at a designated trigger point and the user accepts. It is not preloaded.

---

## Trigger conditions

Fire when **any** of:

- The user says: *"visualize this"*, *"show me [approach/the plan/why X is failing]"*, *"render this as a diagram"*, *"can I see this"*, *"open it in a browser"*, *"share this with my PM"*.
- The agent offered a visualization at a designated trigger point (table below) and the user accepted via AUQ.
- The user asks to view a specific agent artifact: *"show me the decisions"*, *"open the questions"*, *"visualize the plan"*.

**Never auto-fire.** Always requires explicit user request or accepted offer.

---

## Designated trigger points

| Phase / moment | Source the dispatcher renders | Why it's a trigger |
|---|---|---|
| `phases/plan.md` Phase 1b — symptom comparison table | Synthesized brief: current-state vs target-state table + screenshot refs | Natural "before vs after" — side-by-side palette fits |
| `phases/plan.md` Phase 2b — recommended approach (unconditional offer) | Synthesized brief: the recommended approach with structure | Primary visual surface for the recommendation |
| `phases/plan.md` Phase 5 step 6 — right after `Phase: Review` is written, before the `Plan ready` AUQ | **Composite**: `.forge/{slug}/plan.md` + `DECISIONS.md` + `QUESTIONS.md` (see "Composite source for the post-Plan visualize" below) | Plan is on disk awaiting approval — the human reviewing it should see plan + decisions + open questions in one view |
| `phases/plan.md` Phase 5b — plan-quality gate findings | Synthesized brief from `plan-check.md` (BLOCKER/WARNING findings) | Seeing the goal-vs-plan diff visually helps catch gaps quickly |
| User asks for QUESTIONS / DECISIONS standalone | `.forge/{slug}/QUESTIONS.md` or `.forge/{slug}/DECISIONS.md` | Pure artifact view |
| `phases/design.md` — design doc finalized | `docs/{slug}-design.md` | Same human-artifact problem as plan.md; reuses the skill verbatim |
| `phases/build.md` Phase 1 — checklist render | `.forge/{slug}/plan.md` (Implementation Checklist section) | "Show me what's about to be built" — context check before code changes |
| `phases/build.md` deviation point | Synthesized brief: the two deviation options | Structural choice; side-by-side diagram fits |
| `phases/_entry.md` resume refresher | Synthesized brief from STATUS.md + artifact summary | Optional richer view when user returns after days/weeks |

**Excluded: YOLO end-of-run.** YOLO is handoff mode — no visualize trigger.

---

## Diagram-type hints (non-technical default)

When picking the Mermaid type for the visualization, lean on these hints for the **non-technical** audience (the forge default per `phases/_init.md`). For **technical**, fall back to `plan-to-html/SKILL.md`'s structural 5-row table.

| Visualization is about… | Hint | Why for non-technical |
|---|---|---|
| **A user / customer experience** (new flow, screen change, UX path) | `journey` | Reads as a story arc — "user does X, then Y, then sees Z." No protocol arrows. |
| **How components interact** (sync/async handoff, orchestration, "why the API is failing") — *strong default for system behavior* | `sequenceDiagram` with `autonumber` | Numbered steps; one lane per component; matches the existing default. |
| **A decision or branching policy** (eligibility, gating, conditional rollout) | `flowchart TD` | Top-down; Yes/No edge labels are immediately legible. |
| **Before vs after** (refactor, migration, deprecation) | Two stacked `flowchart LR` blocks, or side-by-side `block-beta` if parallelism is structural | Cognitive task is "what changes" — side-by-side makes it visible without reading the body. |

**De-emphasized for non-technical:** `stateDiagram-v2` (states-and-transitions are an engineering primitive) and standalone `block-beta` (containment is an engineering primitive). These stay in plan-to-html's structural table for technical audiences and standalone invocations.

**These are hints, not rules.** The agent picks based on input content and audience, then surfaces the choice via AUQ.

---

## Pipeline (what the dispatcher does)

1. **Resolve the input source.**
   - **Post-Plan Phase 5 Review-state hint** → **composite source**: stitch `plan.md` + relevant `DECISIONS.md` rows + unanswered `QUESTIONS.md` items into a single Markdown brief (see "Composite source for the post-Plan visualize" below). Pass via `--content`, with `--output = .forge/{slug}/plan.html`.
   - **On-disk artifact** (`.forge/{slug}/plan.md`, `.forge/{slug}/QUESTIONS.md`, `.forge/{slug}/DECISIONS.md`, `docs/{slug}-design.md`) → pass the path to plan-to-html.
   - **Ad-hoc concept** (no on-disk artifact, or a fragment of one) → synthesize a Markdown brief in-memory with a `# Title`, a `## Problem` or `## Context`, and any structural sections the visualization needs. Pass via `--content`.

2. **Pick the diagram type (agent judgment + always-AUQ).**
   - Read the input (plan headings, chat-turn text, artifact contents) plus `audience` from `~/.claude/forge-config.json` (default `non-technical` when no config).
   - For `non-technical`, lean on the hints above. For `technical`, lean on `plan-to-html/SKILL.md`'s structural table.
   - **Always surface the choice via AUQ** — header `"Visualize"`, options: `Yes, as a {recommended type} (Recommended)` / `Yes, as a {alternative type}` / `Skip`.
   - User's choice is binding. Forge writes the chosen ```` ```mermaid ```` block into the Markdown brief passed to plan-to-html. plan-to-html stays audience- and palette-agnostic.

3. **Invoke plan-to-html.**
   - With a path: load `~/.claude/skills/plan-to-html/SKILL.md` and follow it with the path.
   - With ad-hoc content: load `~/.claude/skills/plan-to-html/SKILL.md` and pass `--content` + `--output` (the resolved output path; see below).

4. **plan-to-html writes the HTML and auto-opens it** (`open <path>` on macOS; soft-fail on other platforms or if `open` fails — user gets the path).

5. **Forge confirms in chat:** *"Opened {filename}."* Plus a one-line hint: *"You can reference any `section-…`, `fig-…`, `decision-…`, or `note-watch-out-…` ID in your follow-up."*

---

## Composite source for the post-Plan visualize

When the trigger is **Plan Phase 5 step 6 (Review-state hint)** and the user accepts, build a single Markdown brief that stitches the plan together with its sibling decisions and open questions. Layout:

```markdown
# {plan.md's # heading}

{plan.md body, verbatim, minus its own # title line}

---

## Decisions

{Locked-decisions table from DECISIONS.md, verbatim — only if it has data rows beyond the header}

### Claude's discretion
{Claude's-discretion table from DECISIONS.md — only if it has data rows}

### Deferred ideas
{Deferred-ideas table from DECISIONS.md — only if it has data rows}

---

## Open Questions

### Blocking
{unanswered `- [ ]` items from QUESTIONS.md's Blocking section, verbatim}

### Deferred
{unanswered `- [ ]` items from QUESTIONS.md's Deferred section, verbatim}
```

**Skip-empty discipline.** Drop any section, sub-heading, or table whose underlying source is missing/empty (no data rows; only resolved `- [x]` items). If both `## Decisions` and `## Open Questions` are empty, the composite collapses to a plan-only brief — same shape as the path-only flow. Resolved (`- [x]`) questions are intentionally excluded; they're already in DECISIONS.md.

**Output path:** `.forge/{slug}/plan.html` (the canonical plan view, overwrites). The composite is the new content; the path matches the existing "Plan" canonical artifact entry in Output-path rules below.

---

## Output-path rules

- **Plan / Decisions / Questions** (single canonical artifact per slug) → `.forge/{slug}/{plan|decisions|questions}.html`. **Overwrites** on re-render — the canonical view should match the current state.
- **Design doc** → `docs/{slug}-design.html` (next to the source). Overwrites.
- **Ad-hoc renders** (synthesized briefs):
  - Inside a slug: `.forge/{slug}/visuals/{topic-slug}-{timestamp}.html`.
  - Outside a slug: `~/visualizations/{topic-slug}-{timestamp}.html`.
  - **Timestamped** so multiple "visualize this" calls don't clobber each other. Use `YYYYMMDDHHMMSS` form.

---

## Section IDs are a user-facing mnemonic, not an agent contract

plan-to-html emits stable IDs (`section-…`, `fig-…`, `decision-…`, `note-watch-out-…`). The user can quote them back in follow-ups. The agent answers follow-ups the **same way it answers anything else** — by reading the SOT Markdown in context. No special pattern-matching logic. The user-facing summary mentions the IDs as a hint; that's the entire contract.

---

## One-way contract guardrail

**The HTML is human-only and one-way.** The agent must never read its own HTML output as input to a future decision. Always re-derive from the SOT Markdown (`plan.md`, `DECISIONS.md`, `QUESTIONS.md`, `{slug}-design.md`, or the chat context).

If the agent finds itself about to `Read` a `.html` file under `.forge/`, `docs/`, or `~/visualizations/` to inform a decision — stop and re-derive from the source instead.

---

## Relationship to chat

Chat stays plain text — decisions, updates, tables, plain-English summaries. **No ASCII sketches, no Mermaid in chat.** All visuals route either to source artifacts (Mermaid in `plan.md` / design docs, rendered by IDE/GitHub) or to HTML via this dispatcher (rendered by the browser).

The `_shared.md` `No Mermaid in chat` rule is unchanged. HTML is a **side-channel** (disk file opened in a browser) — not the chat medium, so the rule doesn't apply to it.
