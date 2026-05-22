# Forge — Build Mode

> **When to read this file.** Read at the moment Build mode is entered. Also read `phases/_shared.md` for STATUS.md format and the non-technical-mode contract.

Execute the implementation plan — make the actual code changes.

```
IRON LAW: NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE.

Before claiming any task is done:
  1. IDENTIFY the verification command
  2. RUN it (fresh, complete)
  3. READ the full output, check exit code
  4. VERIFY: does output confirm done?
  5. ONLY THEN: mark - [x] in plan.md
```

The agent cannot mark a checklist item `- [x]` without showing the verification output (command + result + exit code) in the chat trail.

## Prerequisites

- `.forge/{slug}/plan.md` must exist. If it doesn't, warn the user: "No plan found. Run Plan mode first, or provide a plan at `.forge/{slug}/plan.md`." Return to menu.

## Workflow

1. Read `.forge/{slug}/plan.md`.
2. **Check QUESTIONS.md gate**: If `.forge/{slug}/QUESTIONS.md` exists and has any questions (Blocking or Deferred) still marked `- [ ]` (not answered or N/A), stop. Surface the open questions to the user. They must answer or mark N/A before Build proceeds. Deferred questions answered here append to DECISIONS.md (Locked decisions bucket) with `Made In: Build`.
3. If STATUS.md Context has a Design Doc path, read that for additional context.
4. Work through the **Implementation Checklist** in plan.md, checkbox by checkbox:

   **Before starting (unconditional).** Offer: *"Want to see the full plan in HTML before I start?"* via `AskUserQuestion` (header `"Visualize"`, options: `Yes, open it (Recommended)` / `Skip`). If accepted, READ `phases/_visualize.md` and follow it (source → `.forge/{slug}/plan.md`, filtered to the Implementation Checklist section).

   a. Read the target file(s) before editing.
   b. Make the change following the patterns referenced in the checklist item.
   c. **Run the verification command** (the test/lint command for this step, or the full test suite if the step is implementation rather than verification).
   d. **Show the verification output** (command + result + exit code) in chat.
   e. **Only then** mark the item `- [x]` in `plan.md`.

5. **Completion-message format with traceability.** Each completion message references the checklist item ID + the decision row(s) it implements + the verification result:

   > *"Step 3 done: added trial-optin filter (per DECISIONS.md row 2). File: `src/js/widgets/configs/scheduleCExportCard.js`. Verification: `yarn test scheduleCExportCard.test.js` → 4 passed."*

   When `audience: non-technical`, the chat rendering leans on the plain-English summary form (per Plan Phase 3) but still includes the verification line so the user can see tests actually ran. When `audience: technical`, the format above is used directly.

6. **Tightened deviation rule.** If Build needs to deviate from the plan (different file, different approach, missing dependency, etc.), **stop, surface the deviation, propose a path forward, and wait for confirmation.** No quiet drift.

   - When `audience: non-technical`, surface the deviation in the user's own framing — anchored to topics in `What matters`. Example, if `What matters` flagged "visual fidelity": *"I need to deviate — the existing card doesn't have a slot for the new icon. Two options: (a) add a small icon to the right of the title (changes the layout), (b) reuse the existing info-icon position (no layout change but mixes meanings). Given you flagged visual fidelity, I'd recommend (b)."* Then take the choice via `AskUserQuestion` (header `"Deviation"`, options: `{Recommended option} (Recommended)` / `{Alternative option}` — per the contract in `_shared.md`).
   - When `audience: technical`, present technical detail directly. Use the same `AskUserQuestion` shape for the choice.
   - The deviation is then logged to DECISIONS.md (Locked decisions bucket) with `Made In: Build`.
   - **Visualize-offer (optional).** After the deviation chat exchange but before logging, optionally offer: *"Visualize the two options side-by-side?"* via `AskUserQuestion` (header `"Visualize"`, options: `Yes, side-by-side (Recommended)` / `Skip`). If accepted, READ `phases/_visualize.md` and follow it (synthesized brief of the two deviation options).

   **When the deviation requires re-running Plan mode** (the chosen approach is invalidated, scope changed by >2×, the schema/contract assumptions in plan.md no longer hold, or the user explicitly asks to rewind to Plan), the Build agent MUST, in addition to logging the B-row to DECISIONS.md `Build-time deviations`:

   1. **Set `Replan Pending: B{n}`** under Context in `STATUS.md`. This is the durable, machine-readable signal that the dispatcher (`phases/_entry.md`) and resume refresher key on. The B-number MUST match the DECISIONS.md row just written.
   2. Remove `Plan` from the `Completed Modes` table in `STATUS.md`.
   3. Set `Phase: Pick Mode`, `Active Mode: None`.
   4. Append a `Build:` line under Context referencing the B-row, e.g. `Build: paused — see DECISIONS.md row B1 (replan pending)`.
   5. Tell the user one line: *"Build paused. Deviation logged as B{n}. Plan re-opened — pick Plan from the menu to replan, or type `forge` later to resume."*
   6. Do **not** auto-launch Plan mode (Hard Rule 1 still applies).

   The combination of `Replan Pending` set + Plan removed from Completed Modes is what makes the next resume recommend Plan as Option 1, not the next sequential mode after Plan. Plan mode clears the `Replan Pending` bit when it re-finalizes (see `phases/plan.md` Phase 5).

6b. **When verification fails twice on the same item — invoke systematic debugging.**

   The deviation rule above handles *known* deviations the agent can name. This sub-step handles *non-obvious* failures where the agent doesn't yet know what's wrong and would otherwise improvise fixes one after another.

   If a checklist item's verification command fails, fix once and re-run. If it fails again on the same item with the same root signal, do NOT attempt a third improvised fix. Stop and run this protocol:

   **Roles.** The Build agent (parent) owns all file edits and verification re-runs. The debug subagent only diagnoses and returns a recommendation — **it never patches files**. This separation keeps debug noise out of the parent context and keeps a single owner for the `- [x]` checkmark.

   **The 4-step protocol — what the subagent produces:**

   1. **Reproduce.** Capture the exact failing command, exit code, and full output. Save to `.forge/{slug}/debug-{step-N}.md`. *(Subagent writes this file; parent does not.)*
   2. **Trace component boundaries.** Identify the components data flows through (e.g., reducer → selector → component → fixture, or controller → service → repository). For each boundary, log what enters and what exits. Read-only; **never patch**.
   3. **Form hypothesis with evidence.** Name the failing component and the specific signal (mismatched value, missing call, wrong type, env propagation). Write it as one sentence in the debug file.
   4. **Recommend a fix.** Describe the change to make, the file to make it in, and why it fixes the failing boundary. **The subagent does not edit the file.**

   **Structured return format.** In addition to writing `debug-{step-N}.md`, the subagent returns a fixed Markdown block:

   ```markdown
   ## Diagnosis
   Failing component: {component name}
   Failing boundary: {e.g., "test fixture → reducer comparison"}
   Evidence: {one sentence with the specific signal}

   ## Recommended fix
   File: {absolute path}
   Change: {1–3 lines describing what to change}
   Why this fixes it: {one sentence}

   ## Verification
   After applying, run: {exact command}
   Expected pass signal: {exact output line or test name}

   ## Confidence
   High | Medium | Low — {one-line reason}
   ```

   The full trace (raw output, dead-end reads, intermediate hypotheses) lives only in `debug-{step-N}.md`. The structured block is what the parent reads.

   **Subagent input contract.** The subagent receives only: the failing checklist item (one line from plan.md), the verification command, the raw verification output from BOTH attempts, and the file(s) under change. No session history, no STATUS.md, no DECISIONS.md, no other plan.md content. The structured return block is its sole interface back.

   **Parent's consume-side branching by confidence tier:**

   | Subagent confidence + scope | Build agent does |
   |---|---|
   | **High** confidence AND fix stays within the file/approach in plan.md | Apply the fix, re-run verification, mark `- [x]`. Continue. No DECISIONS.md change. |
   | **Medium/Low** confidence, OR fix is a deviation (different file, different approach than the locked plan) | Surface the recommendation to the user (audience-aware framing): *"Debug subagent suggests {change}. Confidence: {tier}. {Note if deviation from plan step N.}"* Then `AskUserQuestion` (header `"Apply fix"`, options: `Apply (Recommended)` / `Revisit`). If applied, log to `DECISIONS.md` Locked bucket with `Made In: Build`. |
   | **Recommended fix applied and verification still fails** | Strike 3 — escalate. Surface in chat: *"Debug subagent diagnosed {hypothesis}, recommended fix didn't hold. The approach may be wrong."* Then `AskUserQuestion` (header `"Three strikes"`, options: `Back to Plan Phase 2b (Recommended)` / `Accept a deeper deviation`). Only this exit triggers a real replan. |

   Three possible exits from the protocol (preserved):
   - **Fix is in scope** — repair, re-run, continue. No DECISIONS.md or plan change.
   - **Fix is a deviation** — feed the diagnosis into the Tightened deviation rule above; log to DECISIONS.md `Made In: Build`.
   - **Three strikes** — escalate to the user as above. Only this case triggers a real replan.

   **Dispatching.** Dispatch as a subagent when (a) parent context is already long, OR (b) the failure spans multiple files/components and would generate substantial trace output. Otherwise run inline (same 4-step protocol, same return shape, just executed by the parent). The dispatch decision does NOT change the role split — even when run inline, **diagnose first, then apply** remains the rule.

7. After all implementation items are checked off, run the test/lint commands listed as the final checklist items.

8. Build is **complete when every checkbox in the Implementation Checklist is `- [x]`** — and only after the Iron Law has been satisfied for each.

9. **End-of-Build code-reviewer subagent.** Behavior controlled by global preference `code_review` (off / advisory / block_critical). Default is `advisory`.

   After all checklist items are `- [x]` and tests/lint pass, dispatch a code-reviewer subagent:

   - **Build the diff window.** The reviewer must see everything that would land on master if shipped right now — committed-on-branch AND uncommitted working-tree changes. Construction:
     - `BASE = $(git merge-base HEAD origin/master)` — last common ancestor with master. Survives rebases; doesn't drift if Build started from a stale master. Don't persist a SHA at Build start; recompute on each invocation so this works after `/clear`. (If the repo's default branch is `main` or another name, substitute accordingly — forge assumes `origin/master` because this repo's `change-process.md` uses it; sniff `git symbolic-ref refs/remotes/origin/HEAD` if the assumption is wrong.)
     - If working tree is dirty (`git status --porcelain` non-empty): `STASH=$(git stash create)` — snapshots staged + unstaged without modifying the working tree on disk. Diff = `git diff $BASE $STASH`.
     - If working tree is clean: diff = `git diff $BASE..HEAD`.
     - Recompute every iteration (N+1 re-review included) so a newly-uncommitted fix is always captured.

   - Dispatch via `Task(subagent_type="general-purpose", prompt=...)` with a self-contained prompt — the reviewer receives no session history, only the plan, decisions, the unified diff built above, and (for iteration N+1) a `dismissed-findings` summary list from prior `code-review-*.md` files so it doesn't re-raise items the user already rejected. The prompt template depends on global `audience`:
     - **`audience: technical`** — adversarial-stance audit: *"Review this diff against the plan and DECISIONS.md. Find every bug, vulnerability, defect, regression, or deviation from the locked decisions. Classify findings as Critical / Important / Suggestion. Quote file:line for each. Do not re-raise items in the dismissed-findings list."*
     - **`audience: non-technical`** — same checks, same severity tiers, customer-impact framing. *"Review this diff against the plan and DECISIONS.md. For each finding, describe the concrete consequence ('if X happens, customers will see Y'). Forbidden: 'vulnerability', 'defect', 'violation' as standalone verdicts. Classify as Critical / Important / Suggestion (must fix / should fix / nice to have). Do not re-raise items in the dismissed-findings list."*

   - **Per-finding output format** (the subagent writes one block per finding; `Status: open` is always the initial value — forge mutates this field as the user disposes each item):
     ```markdown
     ## Finding {n} — {Critical|Important|Suggestion}
     File: {path}:{line}
     Issue: {one-line technical description}
     Consequence: {one-line customer/system impact}
     Status: open
     ```

   - Output is written to `.forge/{slug}/code-review-{n}.md` (n = next free integer — prior iterations are preserved, never overwritten); record the path AND counters in STATUS.md Context (see STATUS.md Format in `_shared.md` for the `Code Review` line spec).

   - Forge surfaces the findings to the user in plain English, then takes the disposition via `AskUserQuestion` (per the contract in `_shared.md`):

     > *"Code review came back with 2 items:*
     > *— Must fix: the new card has no analytics tracking ID. Without it, you can't tell if customers are clicking it.*
     > *— Should fix: the trial-optin filter is duplicated in two places; cleaner to extract a helper."*

     Then `AskUserQuestion` (header `"Code review"`, options: `Apply all (Recommended)` / `Apply must-fix only` / `Skip and ship as-is`). If Critical-only findings exist, drop the `Apply must-fix only` option and use a binary AUQ.

   - **Per-finding disposition.** As the user picks an action for each finding, forge updates the `Status:` field in `code-review-{n}.md` in place:
     - `applied` — fix made, verified.
     - `dismissed` — user rejects the finding ("reviewer is wrong"). Carried into the dismissed-findings list passed to any future iteration.
     - `deferred` — user wants to ship without fixing now; the deferral is acknowledged in the PR body.
     - `open` — initial state, untouched.

     STATUS.md counters update on each disposition (`{n} open, {n} applied, {n} dismissed, {n} deferred`). This makes the loop **resumable across `/clear`** — a fresh session reads STATUS.md, sees outstanding findings, and offers the resume menu (see Resume refresher in `phases/_entry.md`).

   - **Power-through and clear-then-resume are the same flow.** Whether the user dispositions findings in the same conversation or returns hours later after `/clear`, the path is identical: read open findings, pick action, mutate Status field, update counters. No parallel code path.

   - **Receiving-side rules** when consuming the review:
     - Don't say *"You're absolutely right!"* — verify before applying.
     - If the reviewer is wrong, push back with technical reasoning rather than capitulating. Mark `dismissed` only after that pushback, not as a default.
     - Implement one item at a time, test each.

   - **Behavior by setting:**
     - `code_review: off` — skip the sub-step entirely.
     - `code_review: advisory` — run, surface, ask the user. **Default. Does not block Build completion.**
     - `code_review: block_critical` — run; if any Critical findings exist with `Status: open`, Build does not complete until they're addressed (max 3 revision iterations, then user takes over). The iteration counter persists in STATUS.md, so the cap is durable across `/clear` — not per-session.

10. **Write `Last Verified:` stamp.** After Step 9's final iteration (user has dispositioned all findings; no more Apply rounds pending), or immediately after Step 8 if `code_review: off`, append (or replace, never duplicate) a single line in `.forge/{slug}/STATUS.md` Context section:

    ```
    Last Verified: {ISO timestamp} (phase: build) (sha: $(git rev-parse HEAD))
    ```

    Ship's preamble (`phases/ship.md` step 2) reads this to short-circuit the test gate when HEAD still matches and the working tree has no source changes outside `.forge/`. This is the same stamp YOLO Build writes (`phases/yolo.md:262`), so interactive and YOLO flows produce identical Ship behavior.

11. Update STATUS.md: Phase → `Review` (before the AUQ below so resume-from-cold-start works). Then present the summary and ask for approval via `AskUserQuestion` (header `"Build done"`, options: `Approve and continue (Recommended)` / `Revise`). The summary block is the lead text:

    ```
    Build complete.

    Files modified:
    - {path} — {what changed}
    - {path} — {what changed}

    Tests: {pass count} passed, {fail count} failed
    Code review: {N applied / N outstanding / "skipped"}
    ```

    - **On `Approve and continue`** → route into the `_entry.md` Approve handler.
    - **On `Revise`** → stay in Build mode, leave Phase as `Review`, prompt in chat: *"What should change? I can adjust files, re-run tests, or address review items."* Make the adjustments, then re-trigger this same AUQ.

    The existing `code_review: block_critical` gate still runs *before* this AUQ — if Critical findings are open, Build does not reach step 11.

## Skip

If the user already made code changes and just wants to ship, they can skip Build and go straight to Ship.
