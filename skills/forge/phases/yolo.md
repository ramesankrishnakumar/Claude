# Forge — YOLO Mode (per-invocation autonomous run)

> **When to read this file.** Read at the moment YOLO is dispatched from `phases/_entry.md` Step 0. YOLO is triggered by the `yolo` keyword at the **start or end** of the user's invocation message — it is NOT a config preference and NOT a per-slug override. Also read `phases/_shared.md` for STATUS.md schema (only when first writing/reading state).

```
HARD TRUTH: YOLO suspends Hard Rule 1 ("Stop at each mode"). The agent runs
plan → issues → build → review → apply → ship end-to-end. It reports back ONLY
at the end of the run, OR on an unrecoverable blocker (see §6).

YOLO is for SMALL HANDOFF CHANGES. The user has accepted that the agent will
make reasonable assumptions for ambiguous decisions and record them in
DECISIONS.md `Discretion choices`.
```

---

## §0. Iron rule — main agent is an ORCHESTRATOR (non-negotiable)

In YOLO mode the main agent dispatches sub-agents and reads their tiny structured returns. It MUST NOT:

- Call `Edit`, `Write`, or `NotebookEdit` on **any path outside `.forge/{slug}/`**. Source-file edits, test edits, config edits, script edits — all of them go through a sub-agent.
- Hold plan content, source code, or review findings in its own context window. Read **paths**, not bodies. The structured return block (§3) is the only thing the main agent consumes from a sub-agent.
- Skip a sub-agent dispatch on the grounds that *"I already have the context"* or *"this is small enough to do inline."* Even single-file edits go through a sub-agent — the whole point of YOLO is to keep main-agent context bounded so long runs survive `/clear`, compaction, and resume.

The ONLY files the main agent writes directly:

- `.forge/{slug}/STATUS.md` (state transitions, phase tracking)
- `.forge/{slug}/forge-config-snapshot.json` (one-shot snapshot at §4)

**Self-check at every phase boundary.** Before each §5.x dispatch, the main agent says (silently): *"My next action is `Task(...)`, not `Edit(...)`. If I am reaching for `Edit` on a source file, I have assumed the wrong role — STOP and dispatch."*

**Plan policy: strict.** §5.2 (Plan) is non-negotiable sub-agent territory. Even when Explore returned a complete map and the main agent feels it could write `plan.md` inline, it MUST dispatch a Plan sub-agent. The cost of a redundant disk-read is trivial; the cost of a bloated main-agent context is run-ending.

**Build policy: strict.** §5.4 (Build) is the highest-temptation phase to absorb (the source files are right there). The main agent NEVER edits source files in YOLO. Build sub-agents do, and only Build sub-agents do.

**No-skip policy: strict.** Every §5.x sub-agent dispatch is mandatory unless the spec text itself names a condition for skipping (e.g., §5.6 fires only when Critical/Important findings exist). The main agent MUST NOT skip (§5.3 Issues), §5.5 (Code review), or any other phase on the grounds that the change is "small," "trivial," "a handoff," or "doesn't need a ticket." The HARD TRUTH framing of YOLO as *"for small handoff changes"* sets user expectations about agent assumptions — it does NOT authorize phase skipping. If a phase fails or is genuinely impossible (e.g., Issues identity not configured), it goes through the §6 unrecoverable-blocker path — never a silent skip.

**Why this matters.** Past runs drifted: main agent wrote the plan inline, then "since I have the context" did Build inline too, then ran out of context before Ship. The Iron rule above is the load-bearing rule that prevents this. If the rule and the §5.x dispatch templates conflict in any future revision, this rule wins.

---

## 1. What you've inherited from entry

By the time this file is read:

- The slug has been derived from the invocation (the `yolo` keyword has been stripped).
- `.forge/{slug}/STATUS.md` has been created with:
  - `Phase: Mode Running`
  - `Active Mode: YOLO`
  - `Context: YOLO Run: phase=init, status=in-progress`
- The user's invocation message (minus the keyword) is the input. Extract:
  - **Goal** — one sentence summarizing the customer outcome / change.
  - **What matters** — non-negotiables and constraints in the user's own words.
- Write Goal + What matters into STATUS.md Context. Do NOT ask follow-up questions — the user opted into YOLO.
- **Symptom decomposition.** If the user named multiple distinct symptoms, enumerate them silently into a `Symptoms` Context field. No confirmation prompt back to the user (YOLO contract).

---

## 2. Status update protocol — the user's only window

Between every sub-agent dispatch the main agent emits exactly **one short line** (≤ 1 line) in this format:

```
YOLO • {phase} • {one-line state}
```

Examples:
- `YOLO • Exploring codebase…`
- `YOLO • Plan ready (3 files, M complexity). Spawning Issues + Build in parallel.`
- `YOLO • Build complete (12 files changed, 47/47 tests pass). Running code review.`
- `YOLO • Review found 1 must-fix; applying.`
- `YOLO • Re-review clean. Shipping.`
- `YOLO • PR opened: {url}`

Discipline: **never** quote plan content, code-review findings, code diffs, or sub-agent return blocks in the user-facing text. If the user wants detail mid-run they `cat .forge/{slug}/STATUS.md` or read the artifact files.

---

## 3. Sub-agent contract — files are the inter-agent bus

The main agent stays clean by treating `.forge/{slug}/` as the **primary communication channel** between sub-agents.

### Every sub-agent dispatch passes ONLY:

1. The slug path (e.g., `.forge/my-feature/`).
2. The list of files the sub-agent must READ (by path).
3. The list of files the sub-agent must WRITE (by path).
4. A one-paragraph job description (what it's doing, the YOLO contract for that phase).

It does NOT pass:
- Verbatim Goal / What matters (the sub-agent reads them from STATUS.md).
- Upstream sub-agent output (read from disk).
- Code, plan content, review findings, or diffs (read from disk).

### Every sub-agent returns to the main agent ONLY:

A tiny structured block (≤ 10 lines):

```markdown
## YOLO Sub-agent Return
phase: {explore|plan|issues|build|review|apply|ship}
status: ok | partial | blocked
summary: {one line}
files_written: [path1, path2, ...]
next_action: {one line if blocked, else "continue"}
```

The main agent reads this block and decides the next dispatch. It does NOT receive code, full plan content, or full review findings. The main agent's context stays bounded regardless of feature size.

### Every sub-agent updates STATUS.md on entry and exit:

- On entry: update `Context: YOLO Run: phase=<phase>, status=in-progress`.
- On exit: update to `phase=<phase>, status=ok` (or `blocked`).

This makes resume-after-`/clear` trivial — see §9.

### Dispatch skeleton (use for every §5.* dispatch)

Every §5.x sub-agent dispatch MUST use this exact shape. The §5.x bodies below specify only the per-phase **delta** (description, READ list, WRITE list, JOB summary, YOLO contract clauses). Wrap them with this skeleton:

```
Task(
  subagent_type="<from §5.x>",
  description="<from §5.x>",
  prompt="""
You are the YOLO <phase> sub-agent for forge slug `{slug}` in the current working directory.

READ:
<paths from §5.x READ list>

JOB:
<JOB summary from §5.x>

YOLO contract:
<contract clauses from §5.x>

Files to WRITE:
<paths from §5.x WRITE list>

On entry: update `.forge/{slug}/STATUS.md` Context to `YOLO Run: phase=<phase>, status=in-progress`.
On exit: update to `status=ok` (or `blocked`).

Return ONLY the structured block:

## YOLO Sub-agent Return
phase: <phase>
status: ok | partial | blocked
summary: {{one line}}
files_written: [list of paths]
next_action: continue | {{one line if blocked}}
"""
)
```

Substitute `{slug}` everywhere it appears. Do not modify the structured-return shape; downstream phases parse it.

---

## 4. Pre-flight: load identity for sub-agents

Before dispatching the first sub-agent, the main agent reads `~/.claude/forge-config.json` and writes a one-shot summary into `.forge/{slug}/forge-config-snapshot.json` (just the `identity` and `issues` blocks needed by Issues and Ship). Sub-agents read this snapshot rather than the live config — keeps their input list small and deterministic.

If `forge-config.json` is missing or `identity`/`issues` blocks are absent, that's an unrecoverable blocker for §5.3 Issues and §5.7 Ship. Surface to the user immediately: *"YOLO blocked: forge identity not configured. Run `forge init` first."*

---

## 5. The autonomous loop — six sub-agent dispatches

### 5.1 Explore (sub-agent)

```
Task(subagent_type="Explore", prompt=<see below>)
```

Job: read `.forge/{slug}/STATUS.md` for Goal + What matters; explore the current codebase to identify relevant files, existing patterns, and a complexity assessment (Simple / Moderate / Complex). Write a 3–6 line summary to `.forge/{slug}/exploration.md`.

Files to READ: `.forge/{slug}/STATUS.md`, current working directory codebase.
Files to WRITE: `.forge/{slug}/exploration.md`.

On return, the main agent emits: `YOLO • Plan ready` is **deferred until §5.2 returns** — between Explore and Plan, the status update is `YOLO • Codebase scanned ({N} files relevant). Drafting plan.`

### 5.2 Plan (sub-agent — MANDATORY, see §0)

**Reminder:** Non-negotiable sub-agent territory. Even if Explore left a complete map in your context, dispatch a fresh sub-agent that re-reads `exploration.md` from disk. Do NOT write `plan.md` inline.

**Wrap with §3 dispatch skeleton.** Per-phase delta:

- **subagent_type:** `general-purpose`
- **description:** `YOLO Plan: produce plan.md + DECISIONS.md`
- **READ:**
  - `.forge/{slug}/STATUS.md` — Goal, What matters, Symptoms (if present)
  - `.forge/{slug}/exploration.md` — codebase map from Explore
  - `phases/plan.md` — for Phase 3 plan.md schema
  - `phases/_shared.md` — for DECISIONS.md three-bucket format
  - relevant source files referenced by exploration.md (paths only; no body paste-back)
- **WRITE:** `.forge/{slug}/plan.md`, `.forge/{slug}/DECISIONS.md`
- **JOB:** produce `plan.md` per `phases/plan.md` Phase 3 schema and `DECISIONS.md` per `phases/_shared.md` three-bucket format. Both artifacts go to disk.
- **YOLO contract:**
  - **Skip QUESTIONS.md.** No blocking questions. Genuinely blocking ambiguity → return `status: blocked` with a one-line reason.
  - **Discretion bucket.** Ambiguous calls go in DECISIONS.md `Claude's discretion` with `Made In: YOLO-Plan` and a one-line rationale. Do NOT ask the user.
  - **No Phase 2b comparison.** Pick the recommended approach; capture alternatives in plan.md `## Approach Alternatives`.
  - **Symptom coverage.** If STATUS.md has a `Symptoms` field, every numbered symptom must be addressed by the plan OR appear as a row in DECISIONS.md `Deferred ideas`.

After this sub-agent returns `status: ok`, the main agent appends a row to STATUS.md's Completed Modes table: `| Plan | plan.md | {ISO timestamp} |`. The artifact path is recorded in the Context section, not the row.

After §5.2 returns `status: ok`, the main agent dispatches §5.3 and §5.4 **in parallel** (both as independent sub-agents in a single tool-call message).

### 5.3 Issues (sub-agent — MANDATORY, see §0; parallel with §5.4)

**Reminder:** Issues is the most-commonly-skipped phase because tiny changes "feel" like they don't need a ticket. They do. Per §0 No-skip policy, the only bypass is the §4 pre-flight blocker (missing identity).

**Wrap with §3 dispatch skeleton.** Per-phase delta:

- **subagent_type:** `general-purpose`
- **description:** `YOLO Issues: file GitHub issue(s) via manage-issues`
- **run_in_background:** `true` (background; Ship blocks on it later if still in flight)
- **READ:** `.forge/{slug}/plan.md`, `.forge/{slug}/forge-config-snapshot.json`, `~/.claude/skills/manage-issues/SKILL.md`
- **WRITE:** `.forge/{slug}/issues.json` with shape:
  ```json
  {
    "status": "in_progress" | "complete" | "failed",
    "tickets": [{"key": "#123", "title": "..."}, ...],
    "started_at": "{ISO}",
    "finished_at": "{ISO or null}",
    "error": "{message if failed, else null}"
  }
  ```
- **JOB:** create Issues tickets via the `manage-issues` skill; write `issues.json` as the single source of truth for ticket keys.
- **YOLO contract — always fires.** Issues fires for every YOLO run regardless of plan complexity, scope, or "feel." The Simple-plan heuristic below determines ticket *count* (one story), not whether Issues runs at all. The only path that bypasses §5.3 is the §4 pre-flight blocker (missing `forge-config-snapshot.json` identity), which surfaces to the user as an unrecoverable blocker — not a silent skip.
- **YOLO contract — ticket breakdown heuristics** (interactive Issues mode requires user approval; YOLO uses these defaults):
  - One story per major Section in plan.md's Implementation Checklist.
  - Test/lint verification items roll up into the last story.
  - Simple plans (≤ 4 checklist items) → exactly one story.
  - Story sizes default from plan.md `Complexity`: Simple → S, Moderate → M, Complex → L.

After this sub-agent returns (regardless of `status: complete` or `status: failed`), the main agent appends a row to STATUS.md's Completed Modes table: `| Issues | manage-issues | {ISO timestamp} |`. The Issues File field in Context still points at `issues.json` for the actual keys/status.

On failure: `status: "failed"` + `error: "{message}"`. Main agent commits with `ISSUE-PENDING` placeholder at Ship time and surfaces the failure in the end-of-run report.

### 5.4 Build (sub-agent — MANDATORY, see §0; parallel with §5.3)

**Reminder:** Highest-temptation phase to absorb. The main agent NEVER edits source files in YOLO. Even one-line edits go through this sub-agent. If you find yourself reaching for `Edit` on a source file, STOP — dispatch.

**Wrap with §3 dispatch skeleton.** Per-phase delta (split into multiple sub-agent dispatches if plan Sections are independent — e.g. one Build sub-agent per Section):

- **subagent_type:** `general-purpose`
- **description:** `YOLO Build: implement plan.md checklist`
- **READ:**
  - `.forge/{slug}/plan.md` — full Implementation Checklist
  - `.forge/{slug}/DECISIONS.md` — Locked decisions (must honor) + Claude's discretion (context)
  - `phases/build.md` — for Iron Law preamble (verification rules) and Step 6b (4-step debug protocol)
  - source files referenced in plan.md
- **WRITE:**
  - source files in the working tree (Build is the only sub-agent that edits source code)
  - `.forge/{slug}/plan.md` (mark items `- [x]` after fresh verification passes)
  - `.forge/{slug}/DECISIONS.md` (append deviation rows)
- **JOB:** implement EVERY `- [ ]` item in plan.md's Implementation Checklist. Per-item workflow: make the change → run the verification command per `phases/build.md` Iron Law (fresh evidence required before marking `- [x]`) → on failure, follow `phases/build.md` Step 6b 4-step protocol; three strikes = return `status: blocked`. Stop when all items are `- [x]` and full test + lint pass.
- **YOLO contract:**
  - Deviations from plan → append a row to DECISIONS.md `Claude's discretion` with `Made In: YOLO-Build` + one-line rationale, then continue. Do NOT ask the user.
  - Do NOT run code review (§5.5 owns it). Do NOT commit / open PR (§5.7 owns it).
  - **Last Verified stamp.** After the final test + lint run passes, append (or replace, never duplicate) a single line in `.forge/{slug}/STATUS.md` Context section:
    `Last Verified: {ISO timestamp} (phase: build) (sha: $(git rev-parse HEAD))`
    This is the freshness signal Ship's gate reads in `phases/ship.md` step 2. Without it, Ship will re-run tests.

After this sub-agent returns `status: ok`, the main agent appends a row to STATUS.md's Completed Modes table: `| Build | plan.md (all - [x]) | {ISO timestamp} |`.

After §5.3 and §5.4 both return, the main agent emits: `YOLO • Build complete ({N} files, {pass}/{total} tests pass). Running code review.`

If (§5.3 Issues) is still in flight when §5.4 (Build) returns, that's fine — Issues can finish in the background. The main agent proceeds to §5.5 immediately and only blocks on Issues at Ship time (§5.7 with a 30s timeout).

### 5.5 Code-review (sub-agent — MANDATORY, see §0)

**Reminder:** The main agent does NOT read the diff. Dispatch a sub-agent to compute the diff window, review it, and write `code-review-{n}.md` to disk. The main agent only reads the counter line + structured return.

**Wrap with §3 dispatch skeleton.** Per-phase delta (substitute `{slug}` and `{n}` — `{n}` = next free integer; first review = 1; iterations preserved, never overwrite prior files):

- **subagent_type:** `general-purpose`
- **description:** `YOLO Code review: write code-review-{n}.md`
- **READ:**
  - `.forge/{slug}/plan.md` — verify scope
  - `.forge/{slug}/DECISIONS.md` — Locked decisions must be honored; deviations should appear in `Claude's discretion`
  - `phases/build.md` Step 9 — for diff-window construction (`git merge-base` + optional `git stash create`) and per-finding format (`## Finding {n} — {Critical|Important|Suggestion}` with File / Issue / Consequence / Status fields)
  - the computed git diff
  - prior `.forge/{slug}/code-review-*.md` files — never re-raise dismissed findings
- **WRITE:** `.forge/{slug}/code-review-{n}.md`
- **JOB:** compute the diff window per `phases/build.md` Step 9, review it against plan.md + DECISIONS.md, surface findings as Critical / Important / Suggestion. Use the per-finding format from `phases/build.md` Step 9. If the repo's default branch is not `master`, sniff `git symbolic-ref refs/remotes/origin/HEAD` and substitute.
- **YOLO contract:** find every issue once; never re-raise items dismissed in prior iterations.

Counter line on STATUS.md after return: `Code Review: code-review-{n}.md ({open} open, 0 applied, 0 dismissed, 0 deferred)` — main agent updates this from the return block.

### 5.6 Apply review (sub-agent) — only if Critical or Important findings exist

If §5.5 produced **any** Critical or Important findings, dispatch a Build-style sub-agent to apply them:

```
Task(subagent_type="general-purpose", prompt="""
Apply findings from .forge/{slug}/code-review-{n}.md to the affected files. Mark
each Status: applied after the fix is verified. Suggestions are not applied —
mark them Status: deferred.

Test re-run policy (conditional, do NOT always re-run):
  - If you modified ONE OR MORE non-doc source files (anything outside .forge/,
    *.md, docs/, README*), run the project's test command and confirm pass
    before returning. On pass, replace the `Last Verified:` line in
    `.forge/{slug}/STATUS.md` Context section with:
      Last Verified: {ISO} (phase: apply) (sha: $(git rev-parse HEAD))
  - If only doc/state files were changed (e.g. README, code-review-{n}.md
    Status fields, deferred-only flips), DO NOT re-run tests. Leave Build's
    existing `Last Verified:` line in place — it remains valid because no
    source changed.
""")
```

Suggestions are deferred — the apply sub-agent leaves them as `Status: deferred` and the main agent records them in DECISIONS.md `Discretion choices`.

After the apply sub-agent returns, decide whether to re-run §5.5:
- **If at least one finding has `Status: applied`** in the mutated code-review-{n}.md → re-run §5.5 once (iteration n+1) to catch regressions introduced by the apply edits. If the re-review surfaces new Critical/Important findings, run §5.6 a second time. **Cap: 2 apply iterations.** A 3rd iteration counts as an unrecoverable blocker (see §6).
- **If no findings have `Status: applied`** (Apply only flipped items to `deferred`/`dismissed`) → SKIP the re-review. Append to STATUS.md Context: `Review-2 skipped (no Critical/Important findings applied).` Code is unchanged from the post-Build state, so the prior review is still authoritative.

Files to READ: `.forge/{slug}/code-review-{n}.md`, source files.
Files to WRITE: source files, `.forge/{slug}/code-review-{n}.md` (mutate Status fields), `.forge/{slug}/STATUS.md` (refresh `Last Verified:` if Apply ran tests).

After the §5.5 + §5.6 review/apply loop converges (no more Critical/Important findings, or the iteration cap is reached without a blocker), the main agent appends a single row to STATUS.md's Completed Modes table: `| Code Review | code-review-{n}.md | {ISO timestamp} |` (`n` = the final iteration's file).

### 5.7 Ship (sub-agent — MANDATORY, see §0)

**Reminder:** The main agent does NOT run `git commit` or `gh pr create`. Dispatch a Ship sub-agent that uses the `commit-and-create-pr` skill.

**Wrap with §3 dispatch skeleton.** Per-phase delta:

- **subagent_type:** `general-purpose`
- **description:** `YOLO Ship: commit + open PR`
- **READ:**
  - `.forge/{slug}/plan.md` — PR body Summary + Test plan
  - `.forge/{slug}/DECISIONS.md` — Locked decisions table for PR body
  - `.forge/{slug}/issues.json` — Issues key for commit/PR title
  - `.forge/{slug}/code-review-*.md` — deferred review items (if any)
  - `.forge/{slug}/forge-config-snapshot.json` — Issues identity
  - `~/.claude/skills/commit-and-create-pr/SKILL.md` — the composed skill (plumbing only; does NOT run tests)
  - `phases/ship.md` — for the `Last Verified` short-circuit gate (step 2) and PR body assembly
- **WRITE:** `.forge/{slug}/STATUS.md` (PR URL field, refreshed `Last Verified:` line if the gate fell through to a fresh test run), git branch + commit + PR (via `commit-and-create-pr`)
- **JOB:** run `phases/ship.md` step 2 gate (short-circuits on Build's `Last Verified:` stamp; only runs tests if the stamp is missing/stale), then commit + open PR via `commit-and-create-pr`. After PR creation, exit. Print `CI: not watched — check {pr-url}/checks`.
- **YOLO contract:**
  - **Pre-flight (Issues poll).** Read `issues.json`. If `status: "in_progress"`, poll at 5s / 15s / 30s. If still in flight after 30s, fall back to `ISSUE-PENDING` placeholder.
  - **Pre-flight (verification).** Read `Last Verified:` from STATUS.md. If sha matches `git rev-parse HEAD` AND `git status --porcelain` shows no source changes outside `.forge/`, the gate is satisfied — skip the test run. Otherwise run tests STRICT (user opted into YOLO). On test/lint failure, attempt one fix; on second failure return `status: blocked`.
  - **PR body assembly:** link to `.forge/{slug}/plan.md`, Locked decisions table from DECISIONS.md, files changed (from plan.md Implementation Checklist), Test plan from plan.md Verification section, optional "Deferred review items" section if any code-review-*.md still has open/deferred findings.

After this sub-agent returns `status: ok`, the main agent appends a row to STATUS.md's Completed Modes table: `| Ship | {PR URL} | {ISO timestamp} |`.

---

## 6. Unrecoverable blockers — the only stop conditions

When any of the following fire, the main agent stops the loop, ensures STATUS.md reflects the partial state, and reports back to the user with the §8 blocker report:

1. **Build verification fails after the 4-step debug protocol's "strike 3" exit** (§5.4).
2. **Code-review apply loop hits 3 iterations without converging** (§5.6).
3. **Plan sub-agent returns `status: blocked`** — typically conflicting Locked decisions or fundamentally underspecified ask that even reasonable defaults can't bridge.
4. **Test/lint preamble at Ship fails after one fix attempt** (§5.7).
5. **Sub-agent dispatch errors** — auth failures, tooling unavailable, missing forge-config.json identity.
6. **Conflicting decisions between Plan and Build** that cannot be resolved by the deviation rule.

The main agent does NOT silently degrade. Every blocker becomes a §8 report.

---

## 7. End-of-run report (success path)

One message at the end:

```
YOLO complete: {title}
• PR: {url}
• Plan: .forge/{slug}/plan.md
• Issues: {refs, or "ISSUE-PENDING — issue creation failed: {reason}"}
• Files changed: {count}
• Tests: {pass}/{total} passed locally; {pass}/{total} in CI ({CI status})
• Code review: {N applied / N deferred / 0 outstanding}
• Discretion choices made (review at .forge/{slug}/DECISIONS.md):
  1. {one-line each, max 5}
  ... ({K} more in DECISIONS.md)
```

Then update STATUS.md: `Phase: Done`, `Active Mode: None`, `YOLO Run: phase=complete, status=ok`.

---

## 8. End-of-run report (blocker path)

One message:

```
YOLO stopped at {phase}: {one-line reason}

What's done:
• Plan: {ready / partial / not started}
• Issues: {refs / failed / not started}
• Build: {N of M tasks complete}
• Files changed: {count, if any}
• Code review: {N applied / N outstanding / N/A}

Specific failure:
{2–4 line description, citing files and the blocker condition}

Next:
• Resume interactively: `forge` (no keyword) — picks up at the menu so you can decide.
• Specific suggestion: {e.g., "Investigate the test failure in foo.py:42 — see .forge/{slug}/debug-3.md"}
```

Then update STATUS.md: `Phase: Mode Running` (so a future `forge` invocation shows the Resume refresher), `Active Mode: YOLO`, `YOLO Run: phase={blocked-phase}, status=blocked`.

---

## 9. Resume after `/clear` mid-YOLO

Trivial because of the files-as-bus design.

On next `forge` invocation, `phases/_entry.md` Step 1 detects an active forge with `Phase: Mode Running`. It reads STATUS.md and sees `Active Mode: YOLO` plus `YOLO Run: phase=<phase>, status=<status>`. It re-reads this file (`phases/yolo.md`) and resumes.

**Resume logic (main agent on resume):**

1. Read STATUS.md `YOLO Run` line. Identify `last_completed_phase` (the phase whose `status=ok` is most recently recorded).
2. If `status=blocked`: surface the blocker (re-render the §8 report) and ask via `AskUserQuestion` (header `"YOLO resume"`, options: `Resume autonomous (Recommended)` / `Take over interactively`). Per `_shared.md` contract. If resume → re-dispatch the blocked phase. If take over → fall through to the standard menu.
3. If `status=in-progress`: the sub-agent for that phase was in flight when `/clear` happened. Re-dispatch that sub-agent — sub-agents are idempotent because their inputs are on disk and they overwrite their output artifacts.
4. If `status=ok`: dispatch the **next** phase in the §5 order.

The main agent surfaces the resume to the user with one line:

```
YOLO • Resuming at {phase} (last completed: {prev-phase})…
```

All upstream artifacts (plan.md, issues.json, DECISIONS.md, code-review-*.md) are already on disk — the resumed sub-agent reads them.

---

## 10. What this file does NOT do

- The **main agent** does not load `phases/plan.md`, `phases/build.md`, `phases/issues.md`, or `phases/ship.md` into its context — those files describe interactive runs. **Sub-agents** dispatched by §5.* DO read them (referenced as the source of truth for schemas, the Iron Law, the 4-step debug protocol, the diff-window recipe, etc.) so behaviors stay consistent across interactive and YOLO modes without duplicating content here.
- It does not interact with `~/.claude/forge-config.json` `preferences` block — there is no `yolo` preference any more. The keyword is the trigger.
- It does not show the interactive menu. Hard Rule 1 is suspended for the entire run.
- It does not make decisions about whether to use YOLO. That happened in entry Step 0 the moment the keyword fired.
