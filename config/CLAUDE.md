# User Preferences

## Communication Style
- Keep responses concise, simple, and to the point. Avoid unnecessary explanations — lead with the answer, not the reasoning.
- Use diagrams only when a visual genuinely clarifies more than words alone.

## Work Completion
- When asked to do steps A, B, and C — do ALL of them. Never stop partway thinking the job is done. Re-read the original request before declaring done.
- After running tests, if ANY test fails, fix it. Don't skip failures because you think they're unrelated to your changes — the PR checks will fail either way. Own the green build.

## Parallel Execution & Subagents
- For non-trivial tasks, decompose into independent subtasks and execute them in parallel using subagents where it will meaningfully speed up the work.
- When multiple files need editing, research, or review independently — launch parallel agents rather than working sequentially.
- Use background agents for long-running tasks (tests, builds, broad searches) while continuing other work in the foreground.
- Choose the subagent model based on task complexity:
  - **haiku** — file searches, grep/glob exploration, simple lookups, reading files to extract specific info
  - **sonnet** — moderate reasoning: code review, test writing, multi-file edits with clear patterns, summarization
  - **opus** — complex reasoning: architectural decisions, subtle bug diagnosis, large refactors requiring cross-file understanding, ambiguous or open-ended analysis
- When unsure, default to **sonnet** — it handles most tasks well and is a good cost/capability balance.
- Don't force parallelism where tasks have dependencies — sequential is correct when step N needs step N-1's output.
