# Forge — Entry Point, Resume, Abort, Approve, Rewind

> **When to read this file.** The dispatcher in `SKILL.md` reads this file on every invocation. It contains the always-on entry-point logic (yolo-keyword / detect / create / resume / menu / approve / abort / rewind). Per-mode bodies live in `phases/{plan,issues,design,build,ship,init,yolo}.md` and are read only when that mode runs.

---

## Entry Point

Run this procedure on every invocation.

### Step 0: YOLO keyword detection

Before any other detection, scan the user's invocation message for the `yolo` keyword as a **standalone token** at the **start or end** of the message (case-insensitive). The `forge` prefix, if present, is treated as not part of the message body for this match.

**Match rules** (apply in this order; first match wins):

1. Strip a leading `forge` token (with surrounding whitespace) if present.
2. Match start: `^yolo\b` (the message starts with `yolo` followed by a word boundary).
3. Match end: `\byolo\s*$` (the message ends with `yolo` and optional trailing whitespace, after stripping a trailing `?`/`.`/`!`).
4. Mid-message `yolo` (e.g., *"please yolo this"*) does NOT match — fall through to Step 1.

**Examples:**

| Invocation | Stripped of `forge` | Matches? | Slug derivation source |
|---|---|---|---|
| `forge yolo "change all primary buttons to match theme"` | `yolo "change all primary buttons to match theme"` | start | `change all primary buttons to match theme` |
| `"I want to change all primary buttons to match theme yolo"` | (no leading forge) | end | `I want to change all primary buttons to match theme` |
| `yolo: fix the retry logic in the payment webhook` | `yolo: fix the retry logic in the payment webhook` | start | `fix the retry logic in the payment webhook` |
| `please yolo this` | `please yolo this` | no | (falls through to Step 1) |
| `forge plan and ship a feature` | `plan and ship a feature` | no | (falls through to Step 1) |

**On match — dispatch to YOLO:**

1. Strip the `yolo` keyword and any trailing `:` or whitespace from the description. The remainder is the YOLO description.
2. Derive a slug from the remainder: lowercase, hyphens, max 50 chars (same rule as Step 2).
3. Create the directory: `.forge/{slug}/`
4. Write `.forge/{slug}/STATUS.md` (use the format in `phases/_shared.md`):
   - `Phase: Mode Running`
   - `Active Mode: YOLO`
   - In Context: populate `Goal` and `What matters` from the description (extract verbatim — no follow-up question, the user opted into YOLO).
   - In Context: add `YOLO Run: phase=init, status=in-progress`.
5. **Do NOT show the menu. Do NOT continue to Step 1.**
6. **READ `phases/yolo.md`** and dispatch to it. That file owns the entire run.

**On no match:** continue to Step 1 as documented below.

### Step 1: Detect active forge

Scan the current working directory for `.forge/*/STATUS.md` files whose **Phase** is not `Done`.

- **One active forge found** → Read its STATUS.md. Go to Step 3 (Resume).
- **Multiple active forges found** → Show the list with titles in chat (one line each), then take the pick via `AskUserQuestion` (header `"Active forge"`, options = forge titles, plus a final option `"Create new"`). If >4 active forges, paginate per the contract in `_shared.md` (first AUQ: 3 most-recent forges + `Create new`; "Other" → second AUQ with the remainder). If pick → Go to Step 3. If new → Go to Step 2.
- **No active forge found** → Go to Step 2 (New Forge).

### Step 2: Create new forge

The user must provide a description (from their invocation or by asking).

1. Derive a slug from the description: lowercase, hyphens, max 50 chars.
   Example: "Add retry logic to payment webhook" → `add-retry-logic-to-payment-webhook`
2. Create the directory: `.forge/{slug}/`
3. **Capture Goal + What matters via one open prompt.** Ask exactly:

   > *"What's the experience you want the customer (or user) to end up with?"*

   This single question is audience-agnostic — a non-technical PM hears UX/flow framing; an engineer hears it as a behavioral spec. Do **not** stack "non-negotiable / must look/feel/work like X" framing on top; that reads as a leading question.

   Extract two fields from the answer:
   - **Goal** — one sentence summarizing the customer outcome / change being delivered.
   - **What matters** — free-form list or sentences capturing the success criteria and constraints in the user's own words. Preserve their phrasing.

   **Follow-up rules** (do not ask reflexively):

   1. **Skip the follow-up when the first answer already names at least one concrete user-facing outcome** — a specific cohort, surface, behavior, constraint, or success criterion. One concrete signal is enough; do not pad. Write Goal + What matters and proceed.
   2. **When the follow-up does fire, probe the specific ambiguity in the user's own words** — don't ask a generic catch-all. Use the generic *"Anything else about how this should land for the customer?"* prompt only as a last-resort fallback when the answer was directional but had no specific ambiguity worth probing.

   Examples:
   - *"Add a new contact-expert card for trial-optin customers, only on the QBO dashboard, must include analytics tracking."* → No follow-up. Three concrete signals. Proceed.
   - *"Surface a new feature for trial customers."* → Targeted follow-up: *"Just trial customers in general, or specifically trial-optin?"*
   - *"Add a thing for users."* → Generic fallback: *"What does the customer see or do — and what would make you say 'yes, that's what I wanted'?"*

4. Write `.forge/{slug}/STATUS.md` using the format in `phases/_shared.md` (STATUS.md Format section).
   - Phase: `Pick Mode`
   - Active Mode: None
   - Context section: populate `Goal` and `What matters` from the answer above.

5. **Symptom decomposition (when the user named multiple distinct issues).**

   If the user's first message names two or more concrete symptoms, behaviors, or asks (e.g., *"size and color don't match"*, *"the buttons are off and the spacing is wrong"*, *"login is broken AND the password reset email isn't arriving"*), enumerate them as a numbered checklist back to the user before any other work:

   > *I want to make sure I capture every issue you mentioned. Reading your message back as a checklist:*
   >
   > *1. {symptom 1, in user's own words}*
   > *2. {symptom 2}*
   > *3. {symptom 3}*
   >
   > *Did I miss anything? Anything I split that should be one item, or merged that should be separate?*

   Wait for confirmation. Add the confirmed list to `STATUS.md` as a new field under Context: `Symptoms` (a numbered list, separate from Goal and What matters). Symptoms is an EXPLICIT promise that every numbered item gets addressed, mentioned, or marked out-of-scope by plan time.

   **When to skip.** If the user's message names only one issue or one fuzzy goal, skip this — Goal + What matters already capture it. Don't pad single-issue tasks with a fake checklist.

   **Why this exists.** Without explicit decomposition, the agent tends to fixate on the most visually obvious symptom and declare done. The numbered list becomes the verification target for Plan mode and Build mode.

6. Tell the user:

   > *Forge created: `.forge/{slug}/`*
   >
   > *Context is saved on disk — feel free to `/clear` or start a new chat any time. Just type `forge` to resume.*

7. Go to Step 4 (Show Menu).

### Step 3: Resume existing forge

Read `.forge/{slug}/STATUS.md` and dispatch by Phase:

| Phase | Action |
|-------|--------|
| `Pick Mode` | Go to Step 4 (Show Menu) |
| `Mode Running` | Read Active Mode. Show the Resume refresher (below) when applicable, then tell user: "Resuming {mode} mode." Go to the matching mode section (READ `phases/{mode}.md` first). **YOLO note:** if `Active Mode: YOLO`, READ `phases/yolo.md` and follow its §9 Resume logic — emit the one-line `YOLO • Resuming at {phase}…` status update instead of the standard refresher. |
| `Review` | Show the Resume refresher (below) when applicable, then tell user: "{mode} output is ready for review at {path}." Wait for approval or changes. |
| `Done` | Tell user: "This forge is complete." Show the summary. |

If the active mode produced artifacts in a previous session, check what exists on disk before restarting the mode from scratch.

#### Resume refresher (3-line orientation)

When resuming, instead of just saying *"Resuming {mode} mode,"* show a 3-line refresher pulled from STATUS.md and the current artifacts. Helps both audiences — a non-technical user re-loads context after days/weeks; an engineer picks up yesterday's work without re-reading files.

**Format:**

> *Picking up where you left off.*
>
> *• **Goal:** {Goal field from STATUS.md}*
> *• **Where we are:** {Active Mode + position — e.g. "Build mode, step 3 of 7" or "Plan mode, Phase 2b — option comparison"}*
> *• **Last decision:** {most recent Locked-bucket row from DECISIONS.md} — {User Reason in user's own words}*
>
**Visualize-offer (unconditional).** After the refresher and before the `Resume` AUQ below, offer: *"See a full status view?"* via `AskUserQuestion` (header `"Visualize"`, options: `Yes, open status view (Recommended)` / `Skip`). If accepted, READ `phases/_visualize.md` and follow it (synthesized brief from STATUS.md + artifact summary). Then continue to the `Resume` AUQ.

Then take the choice via `AskUserQuestion` (header `"Resume"`, options: `Continue with {Active Mode} (Recommended)` / `Pick a different mode`). If the user picks "different mode", fall through to the Step 4 menu AUQ.

**Source fields** (all already on disk, no new state needed):

1. **Goal** — `Goal:` line in STATUS.md Context. If missing on a legacy slug, fall back to slug title.
2. **Where we are** — `Phase` + `Active Mode` from STATUS.md, plus a position hint when meaningful: count of `- [x]` vs `- [ ]` items in `plan.md`'s Implementation Checklist (Build mode), or current phase number (Plan mode).
3. **Last decision** — most recently appended row in DECISIONS.md Locked bucket, with its `User Reason` quoted verbatim. If DECISIONS.md does not exist yet (e.g., resuming during early Plan), omit the line entirely rather than fabricating one.

**When the refresher fires:**

- The conversation just started OR the user explicitly typed "forge" / "resume forge" / similar, AND
- STATUS.md shows `Phase: Mode Running` or `Phase: Review` (i.e. there's work in progress).

**When it does NOT fire:**

- Resume happens *within the same conversation* and the user just said "approve, next" — context is still fresh, the standard menu prompt is enough.
- `Phase: Pick Mode` (no active work) — the menu is the right surface, not a refresher.

**Special case: resuming with outstanding code-review findings.**

If `Phase: Review` OR `Phase: Mode Running` AND the `Code Review` line on STATUS.md has any `open` findings, append an outstanding-findings menu to the refresher (read the latest `code-review-{n}.md`, extract each `Status: open` block). The `Mode Running` branch matters because the review file is written in Build Step 9 before Step 10 sets `Phase: Review` — `/clear` between those two steps would otherwise drop the user into the generic refresher.

> *Code review {n} has {N} open findings:*
> *  1. \[Critical] {Issue line} — {File}:{line}*
> *  2. \[Important] {Issue line} — {File}:{line}*
> *  3. \[Suggestion] {Issue line} — {File}:{line}*
>
> *Default: continue disposing — apply, dismiss, or defer per finding (or batch like "apply all critical").*
> *Other options: re-run review on current state (iteration n+1, recomputes the diff), or ship as-is.*

The default action is **continue disposing existing findings** — re-running review (iteration n+1) is a non-default escape hatch that fires only on explicit ask. The iteration counter on STATUS.md is checked first; if the `block_critical` 3-iteration cap is reached, omit the "re-run review" option and surface the cap to the user.

**Special case: resuming with a pending Plan replan.**

If `STATUS.md` Context has `Replan Pending: B{n}` (set ≠ `None` and ≠ empty), Build mode previously paused because the plan's approach was invalidated (see `phases/build.md` Step 6 sub-rule). Append to the refresher:

> *Replan pending — Build-time deviation {Bn} (see DECISIONS.md) requires a Plan replan. Recommending Plan as the next mode.*

Then in Step 4, force `Plan` as Option 1 (Recommended), regardless of its Completed Modes status. Plan's option `description` becomes `[replan needed — see DECISIONS.md row {Bn}] re-brainstorm the approach`.

`Phase: Done` — the existing completion summary handles this.

The refresher format is the same in both `audience: technical` and `audience: non-technical` because the source fields are user-written in plain language regardless of audience. No file paths, no code in the refresher itself.

### Step 4: Show menu

Render the mode menu via `AskUserQuestion` (per the contract in `_shared.md`), paginated 4-at-a-time. **Soft-gate** modes whose prerequisites aren't met by reflecting the status in each option's `description` — never hide modes, never hard-block. Mark completed modes `[done]`. Suggest the next uncompleted, *unblocked* mode in the default order (Plan → Issues → Design → Build → Ship).

**Replan-required override.** If `STATUS.md` Context has `Replan Pending` set to a B-row (not `None`), Plan is the Recommended Option 1 regardless of its Completed Modes status. Plan's `description` becomes `[replan needed — see DECISIONS.md row {Bn}] re-brainstorm the approach`. This overrides the default Plan→Issues→Design→Build→Ship sequencing. Plan mode clears this bit when it re-finalizes (see `phases/plan.md` Phase 5).

**Pagination.** Pick the 4 most-relevant modes for the first `AskUserQuestion`:
- Option 1 (Recommended): the suggested-next mode — the first uncompleted, unblocked mode in the default order, or `Done` if all are complete. Suffix label with `(Recommended)`.
- Options 2–4: the next 3 modes in the default order (Plan → Issues → Design → Build → Ship → Done), excluding the one already used as Option 1 and excluding any modes that are not yet relevant (e.g., during a fresh forge with no plan, prefer Plan/Issues/Design/Build over Ship/Done). Always include `Done` if it fits in the first 4; otherwise it goes in the second AUQ.
- Header: `"Next mode"`.
- If the user picks the harness-provided "Other" (signalling they want a different mode), raise a second `AskUserQuestion` containing the remaining unrendered modes (header `"Other mode"`).

**Status annotations** are written into each option's `description` field (NOT the label):

| Mode | `description` when completed | `description` when prerequisite missing |
|---|---|---|
| Plan | `[done] — brainstorm the approach` | `brainstorm the approach` |
| Issues | `[done] — create or link GitHub issues` | `[needs a plan first] create or link GitHub issues` if `.forge/{slug}/plan.md` does not exist |
| Design | `[done] — write a design doc` | `[needs a plan first] write a design doc` if no `plan.md` |
| Build | `[done] — implement the code changes` | `[needs a plan first] implement the code changes` if no `plan.md` |
| Ship | `[done] — commit and create a PR` | `[needs Build complete] commit and create a PR` if Build not in Completed Modes |
| Done | — | `wrap up this forge` (always available) |

When the user picks:
- **Mode is unblocked or completed:** Update STATUS.md (Phase: `Mode Running`, Active Mode: the chosen mode). **READ `phases/{mode}.md` before executing**, then run the matching mode.
- **Mode is annotated as blocked:** do NOT silently run it. Acknowledge the prerequisite and offer the unblocking mode via a follow-up `AskUserQuestion` binary (header `"Blocked"`, options: `Start {unblocking mode} (Recommended)` / `Pick a different mode`). On "different mode", re-raise the menu AUQ. Do not run the blocked mode under any circumstance.
- **Done**: Go to Step 5 (Complete).

### Step 5: Complete

1. Update STATUS.md: Phase → `Done`, Active Mode → None.
2. Print a summary of everything produced:

```
Forge complete: {title}

Artifacts:
- Plan: {path or "skipped"}
- Issues: {refs or "skipped"}
- Design Doc: {path or "skipped"}
- Google Doc: {url or "skipped"}
- Build: {complete or "skipped"}
- PR: {url or "skipped"}
```

### Abort

If the user says "abort", "drop it", or "cancel this forge":

1. List all active forges (`.forge/*/STATUS.md` where Phase ≠ Done) in chat (title + slug per line).
2. Take the pick via `AskUserQuestion` (header `"Forge to abort"`, options = forge titles). Paginate per the `_shared.md` contract if more than 4 active forges exist.
3. Confirm via `AskUserQuestion` binary (header `"Confirm delete"`, options: `No, keep it (Recommended)` / `Yes, delete .forge/{slug}/`). The Recommended-default is intentionally the safe option — abort is destructive.
4. Only proceed if user picks `Yes, delete .forge/{slug}/`.
5. Run `rm -rf .forge/{slug}/`.
6. Confirm: "Deleted."

### Approve (after any mode)

> Most mode approvals now arrive via per-mode `AskUserQuestion` prompts (header `{Mode} ready` / `{Mode} done` — see each phase file's end-of-mode step). This chat-trigger handler is the fallback for sessions resumed via `/compact` or new chat where the AUQ is no longer rendered, and for legacy free-form "approve" utterances. When this handler fires from a fallback path, the steps below are identical.

When the user says "approve", "looks good", "next", "done with this mode", or similar:

1. Mark the mode complete in STATUS.md:
   - Append a row to the Completed Modes table:
     `| {Mode} | {output} | {ISO timestamp} |`
     where `{output}` is:
       - **Plan** → `.forge/{slug}/plan.md`
       - **Issues** → comma-separated refs from `issues.json` (e.g., `#42, #43`)
       - **Design** → `docs/{slug}-design.md` (append ` (+ Google Doc: {url})` if pushed)
       - **Build** → `build complete (sha: {short})`
       - **Ship** → PR URL
   - Set Phase → `Pick Mode`, Active Mode → None.
2. Show the session continuity hint in chat, then re-render the menu via the **Step 4 `AskUserQuestion` flow** (annotations recomputed from STATUS.md and on-disk artifacts):

```
{Mode} complete.

If your context is getting long:
  - Claude Code: /compact or /clear, then say "forge" to resume
  - Cursor: start a new chat — forge auto-resumes from STATUS.md
```

Then call `AskUserQuestion` exactly as documented in Step 4 (header `"Next mode"`, recommended-first, paginate 4-at-a-time, status in descriptions). Do NOT print a numbered list here.

---

## Mid-flow rewind handler

Users change their minds while talking. The skill must handle *"back up,"* *"rethink,"* *"wait, actually,"* *"start over from {point}"* as explicit rewind requests, not as content for the current question.

**Three rules:**

1. **Recognize rewind signals.** When the user says any of the phrases above, pause forward progress. Do not write to disk. Do not interpret the rewind phrase as an answer to the pending question.

2. **Confirm the rewind point before acting.** Don't rewind silently. Ask via `AskUserQuestion` (header `"Rewind to"`, options: `Nearest point: {e.g., Phase 2b — option comparison} (Recommended)` / `One phase back: {e.g., Phase 1 — brainstorm}` / `All the way: forge-create`). Let the user pick the scope.

3. **When the rewind is confirmed, preserve everything before the rewind point and clear/supersede everything after.** Apply this consistently across all artifacts.

**Scope: rewind affects only the live conversation and STATUS.md.** Plan-mode artifacts (plan.md, QUESTIONS.md, DECISIONS.md, plan-check.md) are written **at the end** of their respective phases — they don't exist yet during a mid-Plan rewind, so there's nothing to update for them. Downstream artifacts (GitHub issues, design doc, build state, PR, past code reviews) sit past the commitment threshold — those don't get rewound silently either.

**The only file the rewind handler touches is STATUS.md, and only conditionally:**

| What changed | What gets updated in STATUS.md |
|---|---|
| Position (Phase, Active Mode) — always changes on rewind | Update `Phase` and `Active Mode` to reflect the new rewind point. Update `Completed Modes` if a mode that had been marked complete is being re-opened. |
| Goal — only if the user's rewound conversation refined or contradicted the originally captured goal | Update `Goal` line to match the new direction. If unchanged, leave it. |
| What matters — only if non-negotiables shifted (e.g., the rewound direction added or removed a must-have) | Update `What matters` line. If unchanged, leave it. |

**The default is: don't update STATUS.md fields that didn't change.** Detect *whether* goal or what_matters shifted in the rewound conversation. If the rewind was a course correction within the same goal (e.g., "let me reconsider the option comparison" but the customer outcome is the same), STATUS.md only needs the Phase / Active Mode bump.

**The user never loses Goal + What matters** unless they explicitly rewind all the way to forge-create and re-describe the feature.

**When rewind is offered.** The rewind handler is offered when the user signals reconsideration during forge-create or any Plan phase. Once Issues mode, Design mode, Build mode, or Ship mode has produced output, surface the commitment via chat (*"You've already {filed Issues / written the design doc / committed code / opened a PR}."*) and take the path via `AskUserQuestion` (header `"Post-commit"`, options: `Walk through what to change (Recommended)` / `Abort this forge and start a new one`) — i.e., don't silently rewind past a commitment threshold.

**Distinct from Abort.** The Abort flow (above) deletes the entire `.forge/{slug}/` directory after explicit confirmation. Rewind is the lighter alternative — it just resets the position in the conversation. Offer rewind first when the user signals reconsideration during Plan; abort is the right answer when the user wants to drop the forge entirely or has already crossed a commitment threshold.
