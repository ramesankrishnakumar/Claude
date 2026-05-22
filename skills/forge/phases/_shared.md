# Forge — Shared Schemas & Cross-Phase Rules

> **When to read this file.** Read on first state-file write or read in any mode (it's small — schemas + formats + the non-technical-mode chat contract). Do NOT preload other phase files.

---

## QUESTIONS.md Format

```markdown
# Questions: {title}

## Blocking
<!-- Must be resolved before plan.md is finalized -->
- [ ] {question} — raised during Plan brainstorm
      Context: {why it matters}

## Deferred
<!-- Must be resolved before Build starts -->
- [ ] {question} — raised during Plan brainstorm
      Context: {what decision it affects}
```

Resolution states:
- `- [x] Answer: {answer}` — question answered; decision recorded in DECISIONS.md
- `- [x] N/A` — user confirmed not applicable

---

## DECISIONS.md Format

```markdown
# Decisions: {title}

## Locked decisions (you decided these — implementation MUST honor them)

| # | Decision | Option A | Option B | Chosen | User Reason | Made In |
|---|----------|----------|----------|--------|-------------|---------|
| 1 | Implementation approach | {Option A name}: Pros — {list}; Cons — {list} | {Option B name}: Pros — {list}; Cons — {list} | {Option A or B} | {what the user said, e.g. "agreed with recommendation", "simpler to build", "lower risk given timeline"} | Plan |
| 2 | {next decision} | {option} | {option or N/A} | {chosen} | {reason} | Plan |

## Claude's discretion (I made the call — flag if you'd rather decide)

| # | Decision | What I picked | Why | Made In |
|---|----------|---------------|-----|---------|

## Deferred ideas (out of scope for this forge — captured for later)

| # | Idea | Why deferred | Where to revisit |
|---|------|--------------|------------------|
```

**Locked decisions rules:**
- Row 1 is always the approach decision when alternatives were presented in Phase 2b.
- **Option A / Option B** columns capture the full pros/cons — source of truth for the comparison, not just plan.md.
- **Chosen** is the name of the selected option.
- **User Reason** captures the user's own words when confirming — even "same as your recommendation" or "easier to build" is valid and useful.
- If only one approach existed: Option A = the chosen approach with pros/cons, Option B = "N/A — no viable alternative", User Reason = why there was no real choice.
- For non-approach decisions (rows 2+): use Option A/B for the alternatives considered; if binary or N/A, fill accordingly.
- Decisions made in Design mode: append with `Made In: Design`.
- Decisions made in Build mode: agent surfaces the decision, user confirms, then append with `Made In: Build`.
- Never delete rows — mark superseded decisions with `~~strikethrough~~ → {new decision}`.

**Claude's discretion bucket.** Whenever the agent makes a call without explicit user approval (e.g., "I'll reuse the existing helper instead of writing a new one"), record it here so the user can flag it for override. The locked-table format buries discretion choices that the user didn't explicitly approve; this bucket surfaces them.

**Deferred ideas bucket.** Out-of-scope items raised during the forge, captured so they're not lost. Each row records the idea, why it's deferred, and where to revisit (a future forge slug, a backlog ticket, etc.).

---

## STATUS.md Format

```markdown
---
overrides:                         # optional, only if this slug differs from global
  code_review: block_critical      # example
  verification: lenient            # example — relax Build → Ship gate for this slug
---

# Forge: {title}

- **Started**: {ISO date}
- **Phase**: Pick Mode | Mode Running | Review | Done
- **Active Mode**: {mode name or None}

## Completed Modes

| Mode | Output | Completed |
|------|--------|-----------|

## Context

- **Goal**: <one sentence — the customer outcome / change being delivered>
- **What matters**: <free-form non-negotiables / success criteria / constraints in the user's own words>
- **Symptoms**: <optional numbered list, present only if the user named two or more distinct issues — captured at forge-create per `_entry.md` Step 2 sub-item 5 (Symptom decomposition); every numbered item must be addressed or marked out-of-scope by Plan mode>
- **Design Doc**: None
- **Google Doc**: None
- **Build**: None
- **Replan Pending**: None      # `None` (default) or `B{n}` referencing a row in DECISIONS.md `Build-time deviations`. Written by Build mode when a deviation invalidates the plan's approach (see `phases/build.md` Step 6 sub-rule). Read by `phases/_entry.md` Step 3 resume refresher and Step 4 menu — when set, Plan is forced as Option 1 (Recommended) regardless of Completed Modes status. Cleared by Plan mode Phase 5 when it re-finalizes.
- **PR**: None
- **Questions**: None
- **Decisions**: None
- **Code Review**: None         # e.g. `.forge/{slug}/code-review-2.md (3 open, 2 applied, 1 dismissed, 0 deferred, iter 2/3)` — path to latest review file + per-status counters + (when block_critical) iteration cap. Counters update in place as the user dispositions findings; iteration counter persists across `/clear` so the 3-iteration cap is durable.
- **Last Verified**: None       # set by Build mode (regular Step 10 + YOLO) after tests/lint pass. Format: `{ISO} (phase: build) (sha: {short})`. Read by Ship preamble (`phases/ship.md` step 2) and YOLO Ship (`phases/yolo.md` §5.4) to short-circuit the test gate when HEAD matches and working tree has no source changes outside `.forge/`.
- **Plan Quality Check**: None  # path to .forge/{slug}/plan-check.md
- **YOLO Run**: None            # set by `phases/yolo.md` to `phase=<phase>, status=<ok|in-progress|blocked>` during a YOLO autonomous run; used for resume after `/clear`
- **Issues File**: None   # path to .forge/{slug}/issues.json — single source of truth for created Issues keys, set by Issues mode and YOLO §5.3 once the file is written
```

Fields in the Context section are updated by each mode as it runs. "None" means that mode hasn't produced output yet (or was skipped). Path-typed fields (Questions, Decisions, Code Review, Plan Quality Check, Issues File) are set to the file path once created.

The optional `overrides:` frontmatter block lets a single slug override any global preference from `~/.claude/forge-config.json` `preferences` block (e.g., `code_review`, `verification`). Empty/absent = inherit from global.

---

## Non-technical-mode presentation contract

When `audience: non-technical` (in `~/.claude/forge-config.json` `preferences.audience`), forge enforces these rules in chat. In `audience: technical`, all of the below are bypassed.

- **Lead with the answer in plain English.** No file paths, no class names in the first sentence.
- **No code blocks in chat replies** unless the user asks "show me the code." Code lives in the artifacts (`plan.md`, etc.).
- **Errors are an exception to the no-code-blocks rule.** When a command fails, a test crashes, a build errors, a lint command emits non-zero output, or any tool surfaces a stack trace, always show the raw output below a plain-English one-liner. Format: plain summary in customer/feature terms → label `Technical detail (for engineers):` → fenced code block with the unmodified output. The label cues a non-technical user to skip past the block; the block is preserved verbatim for when an engineer needs to be brought in.

  Example:

  > *Tests didn't run — Python can't find the `payments` module. Probably an import path issue. Want me to investigate, or bring in an engineer?*
  >
  > *Technical detail (for engineers):*
  > ```
  > ImportError while loading conftest '/path/to/conftest.py'.
  > conftest.py:5: in <module>
  >     from src.handlers.payments import process
  > E   ModuleNotFoundError: No module named 'src.handlers.payments'
  > ```

- **Define a technical term the first time it appears in this slug**, then use it freely. Within-conversation context is sufficient; no on-disk tracking needed.
- **One next-step question at the end of every reply.** ("Want me to write the plan now?" / "Any of these to revise before we proceed?")
- **Stage-entry one-liner.** First message of each mode states the position: *"Plan mode — we're at brainstorm now (1 of 5 phases). I'll ask one question at a time."*
- **Progress visual** (text only). Tiny `[●●○○○]` indicator at the top of each mode's first message.
- **No Mermaid in chat.** Mermaid diagrams live in `plan.md` and the design doc. **HTML is a side-channel exception** — when the user accepts a visualize offer (see `phases/_visualize.md`), Mermaid renders in the browser, not chat; the rule still holds for the chat medium itself.
- **PM↔technical translation.** Prefer customer-facing language. If the active repo's `CLAUDE.md`, rules, or KB defines a PM↔technical translation table (e.g. a `vocabulary.md`), use it as the canonical source. Forge does not name a specific repo's translation file directly.

- **Hard length cap on chat replies during Plan/Build mode discussion: 8 sentences max** (excluding tables, checklists, and required Technical-detail blocks for errors). If there's more to say, the extra goes to `plan.md` or another artifact, not chat. The principle: chat is for decisions and updates; artifacts are for detail.

- **Option comparison must fit in a 4-row table, not prose.** Replace per-option pros/cons paragraphs with:

  | Option | What it does (one line) | Trade-off (one line, in user's framing) | Effort |
  |--------|-------------------------|------------------------------------------|--------|
  | A | … | … | S |
  | B | … | … | M |

  Followed by a single recommendation sentence: *"I'd go with A — {reason in 8 words or less}."* The `What matters`-anchored framing rule still applies, but as a single-line trade-off, not a paragraph.

- **Completion / done summaries are 3 lines max.** Format:
  > *{What changed, plain English, one line}*
  > *{Verification result, one line}*
  > *{Next-step question, one line}*

  Anything more goes in the artifact's completion section, not chat.

---

## Session Continuity

These rules ensure forge works across session breaks and context limits.

1. **After each mode approval**, show the session continuity hint (see Approve section in `_entry.md`). The user can `/compact`, `/clear`, or start a new chat at any checkpoint.
2. **When resuming**, always re-read `.forge/{slug}/STATUS.md` and the artifacts it references (`plan.md`, `QUESTIONS.md`, `DECISIONS.md`). Never assume conversation history carries over.
3. **Subagent dispatch — what to pass.** When dispatching any subagent (plan-quality gate, code reviewer, debug investigator, design-doc), pass only the artifact excerpts the task actually needs: the specific plan section, the specific DECISIONS.md rows, the relevant diff. Do not pass STATUS.md, the full `plan.md`, conversation history, or prior-mode artifacts the subagent doesn't need. Subagents return ≤200 words; long output (full diffs, full review findings) goes to a file in `.forge/{slug}/`, and the subagent returns only the path.

   Example (Design mode):
   ```
   Task(subagent_type="general-purpose", prompt="Read ~/.claude/skills/design-doc/SKILL.md
   and create a design doc for: {description}. Context: {plan summary}.
   Write to docs/. Return only the file path and a 2-line summary.")
   ```
4. **Never rely on "I remember from earlier."** All state is on disk. If you need something, read the file.

---

## AskUserQuestion contract

When a question has 2–4 discrete, enumerable answers, ask it via the `AskUserQuestion`
tool — not as a chat prompt. When the answer is genuinely open-ended (goals, descriptions,
free-form text, Issues IDs, key=value batches), ask it as a chat sentence.

**Use AskUserQuestion when:**
- Binary yes/no with a clear default.
- 2–4 named options the agent can fully enumerate.
- Pick-from-list (forge to resume, mode to delete, etc.).

**Do NOT use AskUserQuestion when:**
- The answer is free-form text ("what's the experience you want?").
- The answer space is unbounded (issue number, file path, code snippet).
- The "options" are really one option plus a request for edits.

**Formatting conventions:**
- Put the recommended option **first** and suffix its label with `(Recommended)`.
- `header` is ≤12 chars (e.g., "Approach", "Next mode", "Push to Docs").
- Use `multiSelect: true` only when choices are genuinely non-exclusive.
- Never add a manual "Other" option — the harness appends one automatically.
- Use `preview` only when the user needs to visually compare artifacts (ASCII
  mockup, code snippet, diagram variant) — not for plain preference questions.

**More than 4 options:** paginate `AskUserQuestion` 4-at-a-time. First call shows
the 4 most-relevant options (recommended first, suffix `(Recommended)`); if the
user picks the harness-provided "Other", raise a second `AskUserQuestion` with
the remaining options. Never render a 5+ option chat list — users won't run all
options at once anyway, so sequential paginated AUQs are the right shape.

Per-phase nuances (recommended ordering, multiSelect, pagination keys, etc.) are
noted in each phase file where they apply; the rule above is the default.

**End-of-mode approval gates.** Every mode's final step uses `AskUserQuestion`
(header `{Mode} ready` or `{Mode} done` — ≤12 chars; options
`Approve and continue (Recommended)` / `Revise`). The mode updates STATUS.md to
`Phase: Review` *before* the AUQ so state survives mid-prompt session resets
(`/compact`, new chat). The `_entry.md` Approve handler is the fallback for
resumed sessions where the AUQ is no longer on screen. On `Revise`, the mode
stays active (Phase remains `Review`) and re-prompts for changes in chat, then
re-triggers the same AUQ once the artifact is updated.
