# Forge — Plan Mode

> **When to read this file.** Read at the moment Plan mode is entered. Also read `phases/_shared.md` for STATUS.md / QUESTIONS.md / DECISIONS.md formats and the non-technical-mode contract.

```
<HARD-GATE>
Do NOT invoke any implementation skill, write any code, scaffold any project,
or take any implementation action until you have presented an approach and the
user has approved it. This applies to EVERY plan regardless of perceived simplicity.
</HARD-GATE>
```

Interactive brainstorming followed by codebase exploration to produce an implementation plan, a QUESTIONS.md, and a DECISIONS.md.

> Works best when invoked with `/plan` in Claude Code or Cursor's plan mode — the platform suppresses file writes during interactive Q&A, which aligns with this phase's workflow.

## Prerequisites

None. This is typically the first mode.

## Workflow

**Resume / skip check (runs first, before any phase below):**

1. **Fast-path: pending `Plan ready` approval.** If STATUS.md shows `Phase: Review` and `Active Mode: Plan` (i.e., Phase 5 already finalized and the user is returning mid-approval — e.g. after `/compact` or a new chat), skip the Resume/Start-fresh/Skip prompt and re-issue the Phase 5 step 7 `Plan ready` AUQ directly. plan.md, DECISIONS.md, and QUESTIONS.md are already on disk; the user just needs to approve or revise.
2. Otherwise, if `.forge/{slug}/plan.md` already exists, ask via `AskUserQuestion` (header `"Existing plan"`, options: `Resume editing (Recommended)` / `Start fresh (overwrite)` / `Skip — already have a plan`).
3. If the user picks "Skip" → mark Plan complete, return to menu.

**Phase 1 — Triage and codebase exploration**

The principle: **explore the code first, then ask brainstorm questions informed by what was found.** Many brainstorm questions can be answered (or made moot) by reading the code; exploration also surfaces *new* questions worth asking. Front-loading brainstorm Q&A wastes the user's time and risks asking generically when concrete options exist.

**Phase 1a — Triage (does the request need clarification *before* exploring?).**

Quick check: is the request specific enough that the codebase will tell us more than the user can right now? Use `Goal` + `What matters` from STATUS.md as the input.

- **Specific enough → skip to Phase 1b.** If the user named at least one concrete cohort, surface, behavior, file, or success criterion (or those were captured at forge-create), exploration will be productive.
- **Genuinely vague → ask one targeted question first.** Example trigger: *"add some kind of analytics"* — no surface, no cohort, no behavior. Ask exactly one question, framed as helpful (not corrective):

   > *"A quick question to make sure I look in the right place: {specific ambiguity in the user's own words}?"*

   Don't say "your request is vague." Don't bundle multiple clarifications into one prompt. After the answer, proceed to Phase 1b.

**Phase 1b — Visual / styling current-state grounding (gated on symptom topic).**

If `What matters` (or the `Symptoms` list) mentions visual / UX / layout / microcopy / styling drift / "doesn't match Figma" / "looks wrong," AND the user is reporting a visible problem in an existing surface (not greenfield design), do this BEFORE codebase exploration so the explorers can target the right files:

1. **Ask for the current-state artifact** if not already provided:
   > *"To match the {target/Figma}, I need to see what's rendering today. Can you share: a screenshot of the current state, OR the DOM/computed-style inspection of the affected element(s), OR a way for me to run the dev server and reproduce it?"*

2. **Build a per-symptom comparison table** before proposing any fix. For every item in the `Symptoms` list (or, if no symptom list exists, every concrete property the user named), capture:

   | # | Symptom | Current value | Target value (Figma/spec) | Diff? |
   |---|---------|---------------|---------------------------|-------|
   | 1 | font-size of question label | 14px | 16px | YES |
   | 2 | color of question label | #6b6c72 (gray) | #393a3d (primary) | YES |
   | 3 | radio border weight | 1px | 1px | NO — already matches |

   Show the table to the user. Confirm: *"Anything in this table wrong, or anything I missed?"*

   After the table is confirmed, optionally offer: *"Visualize this as a before-vs-after diagram?"* via `AskUserQuestion` (header `"Visualize"`, options: `Yes, side-by-side (Recommended)` / `Skip`). If the user accepts, READ `phases/_visualize.md` and follow it.

3. **Only proceed to Phase 1c once the table is confirmed.** This prevents rushing to a fix based on the most visually loud drift while missing quieter ones.

**When to skip Phase 1b.** Greenfield design ("design a new screen") has no current state — skip the table. If the user pre-emptively provided a complete table or detailed comparison, accept it as-is. If the symptom is not visual/styling, this phase doesn't fire.

**Phase 1c — Announce, then explore the codebase silently.**

Tell the user, in one line, that exploration is starting:

> *"Exploring the codebase first, back in a moment with what I found and any questions it raises."*

Then run codebase exploration without intermediate prompts. The user sees one update when exploration finishes, not a stream of file reads.

1. Explore to inform the implementation plan:
   - For **Simple** changes (1–2 files, well-understood): use a single Explore agent.
   - For **Moderate/Complex** changes: launch up to 2 parallel Explore agents — one to identify target files, one to research existing patterns/conventions.
   - Assess complexity: Simple (1–2 files), Moderate (3–5 files, follows patterns), Complex (6+ files, new patterns, cross-cutting).

2. After exploration returns, summarize back to the user in 3–6 lines: where the relevant code lives, what existing patterns/utilities can be reused, and any concrete options or surprises the code revealed.

**Phase 2 — Brainstorm Q&A (informed by exploration)**

Now that the code is loaded, ask brainstorm questions grounded in concrete findings — not generic openers. Each question cites what was found.

> **AUQ rule (mandatory for every brainstorm question).** If the question has 2–4 enumerable answers (binary, named options, pick-from-list), ask via `AskUserQuestion` per the contract in `_shared.md`. **No exceptions** — the Approach, Trade-off, and Open-questions questions all qualify when their answer space is bounded. Only the catch-all *"Anything else?"* and genuinely open-ended probes stay in chat. Recommended option first, suffix `(Recommended)`.
>
> **Chat-numbering rule (rare).** When a brainstorm turn must ask multiple chat-format questions (the rare case where ≥2 questions are genuinely open-ended and can't be batched into AUQs), prefix each with `Q1`, `Q2`, `Q3` on its own line. **Never** use inline `(a)/(b)` sub-options inside a chat question — split into separate Qs or convert the whole thing to an AUQ.

1. **Approach question** — surface the options *the code revealed* via AUQ:

   > *Chat lead-in:* *"Two paths I see based on the code: (a) extend the existing X in `path/foo.py`, or (b) add a sibling to Y. The trade-off is {X}."*
   >
   > Then `AskUserQuestion` (header `"Approach"`, options: `Extend X in foo.py (Recommended)` / `Add sibling to Y` / `Something else`).

   If exploration revealed only one viable path, say so directly in chat — no AUQ needed: *"Based on the code, there's really one clean path here — {path}. Locking it in unless you push back."*

2. **Trade-off / risk question** — anchor in specific code findings, ask via AUQ when answer is bounded:

   > *Chat lead-in:* *"The existing pattern in `foo.py` does {X}. That's a constraint — fine, or do we need to break it?"*
   >
   > Then `AskUserQuestion` (header `"Pattern"`, options: `Keep the existing pattern (Recommended)` / `Break the pattern for this work`).

3. **Open-questions question** — include any new questions exploration raised, framed as AUQ when bounded:

   > *Chat lead-in:* *"One thing the code surfaced: {finding}. Two ways to handle it: {A} or {B}."*
   >
   > Then `AskUserQuestion` (header `"Open Q"`, options: `{A} (Recommended)` / `{B}` / `Not applicable`).

4. **Anything else?** — final catch-all, kept short, chat-only (genuinely open-ended).

Acknowledge each answer before moving to the next. **Probe vague answers** with the same matrix as before — but the probe wording cites the code findings rather than abstract examples:

| User says | Respond with |
|-----------|-------------|
| "I don't know" | "Based on the code, three options: [A from foo.py], [B from bar.py], [C new]. Which feels closest?" |
| "whatever works" | "Concrete starting point based on the code: [approach citing files]. Match your thinking?" |
| "keep it simple" | "Simplest path I see in the code: [approach]. Any concerns?" |
| "figure it out later" | "This could affect downstream work. Default that's easy to change: [approach citing where the change lands]." |
| "there's only one way" | "Exploration confirmed your read — [approach in `path`] is the clear winner. Locking it in." |

5. After brainstorm, write `.forge/{slug}/QUESTIONS.md` with any questions that remain unresolved.
   - Questions fully answered during brainstorm are NOT written here.
   - Classify each unresolved question as **Blocking** or **Deferred** (see QUESTIONS.md format in `_shared.md`).

**Phase 2b — Approach confirmation (interactive)**

After codebase exploration, before writing plan.md:

1. If the user provided 2 approaches in Phase 1, synthesize what codebase exploration revealed about each.
2. If the user provided 1 approach (or said "figure it out"), check during exploration whether a simpler or meaningfully different alternative exists. If one does, surface it.
3. Present the comparison in chat as the 4-row table from `_shared.md` (non-technical-mode option-comparison rule), followed by a one-sentence recommendation. Then take the choice via `AskUserQuestion` (header `"Approach"`, options: `{Recommended option name} (Recommended)` / `{Alternative option name}`). The chat table is the source of pros/cons; the AUQ takes the binding decision. If only one viable approach exists, skip both the table and the AUQ — state the lock-in directly.

4. **Audience-aware framing of trade-offs.** When `audience: non-technical`, translate technical trade-offs into the user's own framing using topics surfaced in `What matters`:
   - If `What matters` flagged **visual fidelity / layout / microcopy** — surface visual/UX impact ("this approach changes the layout on three screens"; "users see an extra confirmation step").
   - If it flagged **cost / free tier / per-customer compute** — surface cost/scaling impact ("every download adds compute cost, even free-tier"; "this is zero-incremental-cost per customer").
   - If it flagged **measurement / analytics / tracking** — surface data impact ("this version emits clean tracking; this version has gaps you'll have to backfill").
   - If it flagged **scope / capacity / sprint / quarter** — surface scope impact ("this lands in 1 sprint with 1 engineer"; "this needs a partner team and adds 3 weeks").
   - If it flagged **customer-impact / cohort / blast radius** — surface customer-impact framing ("if X breaks, Y also breaks for customers"; "your customers wait longer instead of seeing this in real time").

   When `audience: technical`, present trade-offs in the original technical terms (coupling, latency, complexity, etc.).

5. **Recommendation cites `What matters` directly.** The recommendation should explicitly cite the topic from `What matters` it's optimizing against. E.g., *"Given you said visual fidelity matters most, Option A looks like the right call."* Anchors the recommendation to the user's own stated priorities rather than abstract criteria.

6. **Visualize-offer (unconditional).** After the recommendation, offer: *"Want me to visualize the recommended approach as HTML?"* via `AskUserQuestion` (header `"Visualize"`, options: `Yes (Recommended)` / `Skip`). Fires for **every** audience and **every** complexity. If the user accepts, READ `phases/_visualize.md` and follow it (synthesized brief of the recommended approach; if the structural difference between two options is the crux, the brief covers both). Do not re-offer within the same phase if the user declines.

7. **Symptom coverage check before locking the approach.**

   If `STATUS.md` has a `Symptoms` field with a numbered list, the recommendation must explicitly map each symptom to how the chosen approach addresses it. Use this format in chat:

   > *Coverage check against your stated symptoms:*
   >
   > *1. {symptom 1} → {how this approach fixes it, OR "not addressed by this approach because X"}*
   > *2. {symptom 2} → {how this approach fixes it}*
   > *3. {symptom 3} → {marked out of scope per your earlier confirmation}*
   >
   > *Any of these I'm under-addressing or missing entirely?*

   If any symptom is "not addressed," surface that and ask the user to either expand the approach to cover it, mark it out-of-scope (record in DECISIONS.md Deferred bucket), or pick a different approach. Do not silently drop a symptom.

   **Why this exists.** The agent's confidence ("I recommend Option A") often outpaces verification. Forcing a one-line-per-symptom mapping makes coverage gaps visible — and easy for a non-technical user to scan and challenge.

8. Wait for the user to confirm or redirect. Note exactly what they say — this becomes the **User Reason** in DECISIONS.md.
9. Proceed to Phase 3 with the confirmed approach.

If there is genuinely only one reasonable approach (no viable alternative exists or the user has already ruled out alternatives), skip the comparison and note the approach directly in plan.md's `## Chosen Approach` section without the alternatives table.

**Phase 3 — Draft plan.md**

1. Write `.forge/{slug}/plan.md` incrementally as you work through steps. Don't hold it until the end.

```markdown
# Plan: {title}

**Complexity**: Simple | Moderate | Complex

## Problem
{what and why}

## Approach Alternatives

> Skip this section if there is genuinely only one reasonable approach — write ## Chosen Approach directly.

### Option A — {Name}
{How it works, 2–4 sentences}

**Pros:** {bullet list}
**Cons:** {bullet list}
**Effort:** S / M / L

### Option B — {Name}
{How it works, 2–4 sentences}

**Pros:** {bullet list}
**Cons:** {bullet list}
**Effort:** S / M / L

### Comparison

| Criterion | Option A | Option B |
|-----------|----------|----------|
| Complexity | ... | ... |
| Risk | ... | ... |
| Extensibility | ... | ... |

## Chosen Approach — {Name}
{Why this option was selected. Reference the comparison above.}
→ See DECISIONS.md row 1

## Key Decisions
- Approach choice → see DECISIONS.md row 1
- {decision 2} → see DECISIONS.md

## Implementation Checklist

- [ ] {Step 1}: {file path} — {what to change} (per DECISIONS.md row N)
      Pattern: {existing file or function, for Moderate/Complex}
- [ ] {Step 2}: {file path} — {what to change}
- [ ] {Step 3}: Run tests — exact command, expected output (e.g. `pytest tests/foo.py -v` → 6 passed, 0 failed)
- [ ] {Step 4}: Run lint — exact command, expected output

## Open Questions
→ See QUESTIONS.md
```

> **Mermaid in plan.md is encouraged** when the implementation has a known shape — a 3-step state transition, a multi-repo dependency graph, etc. Per the Visuals section in `SKILL.md`, **Mermaid** diagrams live in `plan.md` and the design doc only — never in chat.

**No-placeholders discipline.** Each checklist item must follow these rules:

- **Each step is one action that takes 2–5 minutes.** Not "implement the auth module" — that's 4 hours and ten decisions.
- **Forbidden words:** "TBD", "TODO", "implement later", "fill in details", "add appropriate error handling", "handle edge cases", "write tests for the above", "similar to Task N". These are plan failures.
- **Code steps must include the code**, not a description of the code. Example: *"Add reducer condition `diwmSubscriptionStatus: ['TRIAL']` to `src/js/widgets/configs/<cardId>.js`"* — not *"update the reducer to filter trial customers."*
- **The final test/lint items must include the exact command and the expected output.** Example: *"Run: `pytest tests/path/test.py -v`. Expected: 6 passed, 0 failed."*
- **Each step that implements a Locked decision references the decision row by ID.** Example: *"(per DECISIONS.md row 1)"*. Prevents tasks drifting from approved decisions.

**Existing checklist rules:**

- Every step is a checkbox: `- [ ]`.
- The final 1–2 items are always the test/lint verification commands.
- Build mode checks off each item as it completes it; Build is done when all boxes are `- [x]`.

**Audience-aware checklist rendering in chat.** When `audience: non-technical`, render the checklist to chat in plain-English summary form (one bullet per step, no code in chat). The file at `.forge/{slug}/plan.md` always contains the full technical detail. Non-technical user sees: *"This adds the trial-customer filter to the card's visibility rule (5 min)."* Engineer sees the actual code in `plan.md`. When `audience: technical`, the chat rendering matches the file.

**Phase 4 — Clarify blocking questions**

1. If QUESTIONS.md has any **Blocking** questions, surface them to the user now (one at a time). The user must answer or explicitly mark N/A before the plan is finalized.
   - **Question format.** If the question has bounded enumerable answers (yes/no, 2–4 named options), ask via `AskUserQuestion` per the contract in `_shared.md`. Always include `Not applicable` as the final option so the user can mark N/A through the same tool. If the question is genuinely free-form (e.g., "What value should X default to?"), ask in chat.
   - **Answered**: mark the question `- [x]` in QUESTIONS.md. Add a row to DECISIONS.md (Locked decisions bucket): Option A = the chosen answer, Option B = "N/A", Chosen = the answer, User Reason = what the user said, Made In = Plan.
   - **N/A**: mark the question `- [x] N/A` in QUESTIONS.md.

Deferred questions are left in QUESTIONS.md for Build mode to gate on.

**Phase 5 — Write DECISIONS.md and finalize**

DECISIONS.md uses three buckets (full schema in `_shared.md`).

1. Write `.forge/{slug}/DECISIONS.md`. **Row 1 of Locked decisions** is always the approach decision (when alternatives existed):
   - Populate Option A and Option B columns with the full pros/cons from the Phase 2b comparison.
   - Set Chosen to the selected option name.
   - Set User Reason to exactly what the user said when confirming (e.g. "agreed with recommendation", "simpler to build", "lower risk given our timeline").
   - If only one approach existed: Option A = the chosen approach with pros/cons, Option B = "N/A — no viable alternative", User Reason = why there was no real choice.
   - Subsequent rows are the other Key Decisions from plan.md.

2. **Claude's discretion bucket.** Whenever the agent makes a call without explicit user approval (e.g., "I'll reuse the existing helper instead of writing a new one"), record it here so the user can flag it for override. Why this matters: the locked-table format buries discretion choices the user didn't explicitly approve.

3. **Deferred ideas bucket.** Out-of-scope items raised during the forge, captured so they're not lost. Each row records the idea, why it's deferred, and where to revisit (a future forge slug, a backlog ticket, etc.).

4. **Never delete rows.** Mark superseded decisions with `~~strikethrough~~ → {new decision}`.

5. **If `STATUS.md` had `Replan Pending: B{n}` set on Plan entry** (i.e., this Plan run was triggered by a Build-time deviation that demanded a replan — see `phases/build.md` Step 6 sub-rule):
   1. Clear it — set `Replan Pending: None` (or remove the line) in STATUS.md Context.
   2. Append a row to DECISIONS.md `Locked decisions` bucket noting which B-row this replan resolved. `Made In: Plan`. Example User Reason: *"Replan triggered by deviation B1; new approach is the adapter pattern (Locked row N)."*
   3. The B-row itself in `Build-time deviations` stays in place (never delete rows) — it's the historical record of why the replan happened.

6. **Update STATUS.md: Phase → `Review`.** Do this *before* the AskUserQuestion below so the state is durable if the user `/compact`s or quits mid-prompt — on resume, `_entry.md` sees `Phase: Review, Active Mode: Plan` and re-issues the AUQ (via the Plan-mode fast-path in step 1 above).

   **Visualize-offer hint (after Phase: Review is written, before the `Plan ready` AUQ).** Modeled on the `/clear` and `/compact` continuity hints. Offer via `AskUserQuestion` (header `"Visualize"`, options: `Yes, visualize as a {agent-chosen type} (Recommended)` / `Yes, as a {alternative}` / `Skip`). If the user accepts, READ `phases/_visualize.md` and follow it (output → `.forge/{slug}/plan.html`, overwrites — the composite view stitches `plan.md` + `DECISIONS.md` + `QUESTIONS.md` per `phases/_visualize.md`'s composite-source section). Then continue to step 7. The existing `Plan ready` AUQ in step 8 is untouched.

7. **Run Phase 5b plan-quality gate.** See the Phase 5b section below for when it runs and what it does. If 5b surfaces findings and the user picks `Revise the plan`, loop back to Phase 3/4/5 and re-enter step 7. If 5b is skipped or the user picks `Proceed as-is`, proceed to step 8.

8. **Ask for approval via `AskUserQuestion`** (header `"Plan ready"`, options: `Approve and continue (Recommended)` / `Revise`). Lead text is audience-aware:
   - **Technical mode:** *"Plan ready at `.forge/{slug}/plan.md`. Review it — approve to continue, or pick Revise and tell me what to change."*
   - **Non-technical mode:** *"Plan written to `.forge/{slug}/plan.md`. The file has the full technical detail (code, file paths) — open it for a 5-min skim if you want to double-check, or trust me and we proceed."*

   - **On `Approve and continue`** → route into the `_entry.md` Approve handler (mark Plan complete in STATUS.md, render the Next-mode menu).
   - **On `Revise`** → stay in Plan mode, leave Phase as `Review`, prompt in chat: *"Tell me what to change — I'll update plan.md."* Re-enter Phase 3/4/5 as needed, then re-trigger this same AUQ.

**Important**: Plan mode does NOT make code changes. It produces plan.md, QUESTIONS.md, and DECISIONS.md only. Code changes happen in Build mode.

**Phase 5b — Plan-quality gate**

After Phase 5 finalizes `plan.md`, spawn a plan-checker subagent that does **goal-backward verification**.

**What it checks:** starting from the user's stated outcome (the Goal + What matters captured at forge-create, plus anything refined during Phase 1 brainstorm), verify that every Locked decision has a task in the plan, every task traces to a decision, and the plan as a whole will deliver the stated outcome.

**Severities (mandatory classification):**
- **BLOCKER** — phase goal will not be achieved if this isn't fixed.
- **WARNING** — quality degraded, fix recommended but proceed.

**Mode:** always **warn** when it runs. Surfaces findings to the user, then asks via `AskUserQuestion` (header `"Plan check"`, options: `Revise the plan (Recommended)` / `Proceed as-is`) — never auto-blocks. The recommended default favors revising because the gate only fires when findings exist. The user decides.

**When the gate runs:**
- Runs by default for **Moderate** or **Complex** plans (3+ files, 5+ checklist items).
- **Skipped by default for Simple plans with ≤1 Locked decision** — the failure mode the gate catches ("tasks listed but goal missed") essentially never shows up when there are 1–2 files and one decision; running the subagent costs 10–20 seconds with near-zero hit rate.
- When skipped, say: *"Plan-quality check skipped — Simple complexity with one decision, low risk of goal-mismatch. Re-run manually any time by saying 'check the plan.'"*
- The user can always trigger the gate manually with phrases like *"check the plan,"* *"verify the plan,"* *"run the plan-quality check"* — even on a Simple plan that would otherwise skip.

The skip rule is **deterministic from the plan itself** (`Complexity` field + Locked-bucket row count) — not a user toggle, not a per-slug setting.

**How to dispatch.** Use `Task(subagent_type="general-purpose", prompt=...)` with a self-contained prompt that includes:
- The Goal and What matters from STATUS.md (verbatim).
- The full contents of `plan.md` and `DECISIONS.md`.
- Instructions: "Verify goal-backward — does every Locked decision have a task that implements it? Does every task trace to a decision or the stated goal? Will the plan as a whole deliver the Goal? Return findings classified as BLOCKER or WARNING. Be specific: name the decision row and the missing/drifted task."
- Instructions: "Flag as BLOCKER any task or decision that uses scope-reduction language ('v1', 'static for now', 'placeholder', 'future enhancement', 'we'll add this later', 'TBD'). Quote the exact phrase. The user confirms whether each is intentional scope or a hidden gap."

**Audience-aware finding framing:**
- **Non-technical:** *"Heads up: you said the new card should appear only for trial-optin customers, but the plan only filters by trial status — opt-in users won't be excluded."* Then `AskUserQuestion` (header `"Update plan"`, options: `Update the plan (Recommended)` / `Proceed as-is`).
- **Technical:** *"BLOCKER: locked decision row 1 specifies `subscriptionStatus: ['TRIAL_OPTED_IN']`, but plan checklist step 3 only filters `subscriptionStatus: ['TRIAL']`. Opt-in users will be incorrectly excluded. Resolve before Build."*

When findings exist, optionally offer: *"Visualize the goal-vs-plan gap?"* via `AskUserQuestion` (header `"Visualize"`, options: `Yes (Recommended)` / `Skip`). If accepted, READ `phases/_visualize.md` and follow it (synthesized brief from `plan-check.md`).

**Iteration cap.** The checker runs once per Plan finalization. If the user revises the plan, the checker re-runs (max 3 iterations, then user takes over). Output is written to `.forge/{slug}/plan-check.md` and the path is recorded in STATUS.md Context.

**Ordering with Phase 5 step 7.** Phase 5b runs *between* Phase 5 step 6 (Phase: Review state flip) and Phase 5 step 8 (`Plan ready` approval AUQ). If 5b is skipped (Simple plan) or the user picks `Proceed as-is`, control falls through to step 8. If the user picks `Revise the plan` at 5b, Plan loops back to Phase 3/4/5 before reaching step 8.

---

## Visuals — Mermaid in artifacts, HTML on demand

**Mermaid diagrams** live in `plan.md` (this file) and design docs (`docs/<slug>-design.md`). They never appear in chat replies — the terminal doesn't render Mermaid; artifact viewers (IDE, GitHub) do.

**Polished HTML rendering** of the plan or any synthesized brief is available on demand via `phases/_visualize.md` — see that file for the full dispatcher spec, trigger conditions, and diagram-type hints. Fires at the designated trigger points across phases (always offered via AUQ; never auto-fires). When 2 options are on the table, the synthesized brief covers the recommended option by default — both if the user explicitly asks, or if the structural difference is the crux.
