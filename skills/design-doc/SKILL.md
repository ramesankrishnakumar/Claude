---
name: design-doc
description: >
  Create a system design document with Mermaid diagrams in the docs/ folder.
  Trigger when user says: design doc, write a design, system design, architecture doc,
  document the design, create a design overview, or describes a feature/system to document.
user-invocable: true
---

# System Design Document

**Goal:** Create a comprehensive system design document following established conventions — Markdown format, Mermaid diagrams, structured sections, and accurate code references.

## Usage

```
/design-doc <topic or goal>
/design-doc               # interactive — will ask what to document
```

---

## Phase 1: Understand the Goal

Before writing anything, establish **why** this design doc exists and **what** it covers. Minimize question rounds — infer what you can, ask only what you can't.

### 1a. Parse input and infer mode

The user's input arrives as `$ARGUMENTS`. Parse it to extract:
- **Topic**: What system or feature to document
- **Mode**: Retrospective (documenting existing code) or Prospective (designing before implementation)
- **Audience**: Engineering (default) or Stakeholder
- **Issue ID**: If mentioned

**Infer the mode from phrasing — only ask when ambiguous:**

| User says... | Inferred mode |
|-------------|---------------|
| "document how chips work", "write up the checkout flow" | **Retrospective** |
| "design a new progress model", "plan the migration approach" | **Prospective** |
| "design doc for feature X" | **Ambiguous** — ask |

**Infer the audience from phrasing — only ask when ambiguous:**

| User says... | Inferred audience |
|-------------|-------------------|
| "design overview", "architecture overview", "make it simple" | **Stakeholder** |
| "detailed design", "technical design", "implementation doc" | **Engineering** |
| "design doc" (unqualified) | **Ambiguous** — ask |

If no arguments are provided, ask a single combined question: **"What should this design doc cover? Are we documenting something that already exists in the code, or designing something new? And who is the primary audience — engineers familiar with the codebase, or stakeholders who aren't?"**

### 1b. Doc modes

| Mode | Status field | Phase 2 focus | Diagram tense | Section emphasis |
|------|-------------|---------------|---------------|-----------------|
| **Retrospective** — documenting code that already exists | `Production` | Explore what the code **actually does** | Present tense ("The routing step calls...") | Detailed Design |
| **Prospective** — designing something before implementation | `Proposed` or `Draft` | Explore the **existing system** the new design integrates with — current patterns, constraints, interfaces, state models | Future tense ("The new handler will...") | Problem Statement + Approach Alternatives + Key Design Decisions |

**Why this matters:**
- **Retrospective**: The code is the source of truth. Every claim must be verified against it. Diagrams describe what **is**.
- **Prospective**: The user's intent is the source of truth. Codebase exploration identifies constraints, existing patterns to reuse, and integration points. Diagrams describe what **will be**.

### 1c. Audience modes

The audience determines how implementation details are presented — it does not change *what* the doc covers, only *how*.

| Audience | Code references | Diagrams | Data structures |
|----------|----------------|----------|-----------------|
| **Engineering** (default) | Function names, class names, file paths are appropriate. Code snippets show contracts and interfaces. | Use actual code names for nodes and components (e.g., `route_node`, `__start__`). | Show as code snippets (Python dicts, JSON config blocks). |
| **Stakeholder** | No code terminology. Describe behavior, not implementation. No function names, variable names, or file paths in prose. | Use descriptive role-based labels (e.g., "Routing Step", "Start"). | Replace with tables showing field names, descriptions, and examples in plain language. |

**Why this matters:** A stakeholder-audience doc that references `_build_navigation_context()` or `config["configurable"]["module_context"]` forces the reader to parse implementation details to understand the design. The same information conveyed as "the system builds a navigation context containing available modules and journey progress" is immediately clear.

**How audience affects later phases:**
- **Phase 2**: Exploration depth is the same — you must understand the code regardless. The difference is in what you surface in the doc.
- **Phase 3**: Writing style, diagram labels, data structure presentation, and appendix inclusion all change.
- **Phase 4**: Self-review checklist includes audience-specific checks.

### 1d. Fill gaps in a single round

After inferring what you can, ask remaining questions **in one message** — not across multiple rounds. Only ask what you can't infer:

| Question | When to ask |
|----------|-------------|
| What's the **GitHub issue or ticket**? | If not mentioned |
| Are there **specific areas** to focus on or exclude? | If scope is broad |
| What **alternatives** were considered or rejected? | Prospective mode only |
| Are there **hard constraints** (latency budgets, backwards compat, config-only)? | Prospective mode only |

Skip questions you can answer from context. If the user's input is detailed enough, proceed directly to 1e with zero questions.

### 1e. Tell the user your plan and build a checklist

Before exploring code, tell the user:
- **Doc mode**: retrospective or prospective (and why you inferred it)
- Where you plan to place the doc (which `docs/` subdirectory)
- What sections you expect to include
- What areas of the codebase you'll explore and why

**Then create a task checklist** tailored to this specific doc. The checklist ensures nothing is missed during execution. Use TaskCreate to track each item. Example for a retrospective doc on chip generation:

```
[ ] Phase 1: Confirm goal, mode, and placement with user
[ ] Phase 2: Explore auth middleware — nodes, state, LLM call
[ ] Phase 2: Explore data flow — entrypoint.py → chip graph → SSE emission
[ ] Phase 2: Explore config registry and feature-flag overrides
[ ] Phase 2: Report findings to user
[ ] Phase 3: Write Introduction + Design Principles
[ ] Phase 3: Write High-Level Architecture with sequence diagram
[ ] Phase 3: Write Detailed Design — one subsection per component
[ ] Phase 3: Write Key Design Decisions
[ ] Phase 4: Run self-review checklist
[ ] Phase 4: Present to user with summary and judgment calls
```

Adapt the checklist to the specific topic — the exploration tasks should name the actual components, and the writing tasks should name the actual sections. Mark each task complete as you finish it so the user can track progress.

Wait for confirmation or adjustments before proceeding.

---

## Phase 2: Codebase Exploration

### For Retrospective Docs (documenting existing code)

**This is the most important phase.** The design doc must reflect what the code actually does, not what you think it does.

#### 2a. Explore the implementation

Use Explore agents (up to 3 in parallel) to thoroughly understand the system:

- **Agent 1**: Core architecture — graph structure, node functions, state models, entry points
- **Agent 2**: Data flow — how data moves between components, state mutations, DB interactions
- **Agent 3**: Integration points — how this system connects to others, SSE events, config loading

For each component, capture:
- **File paths and line numbers** for key functions
- **Actual code patterns** (not assumed ones)
- **State mutations** — what changes, what's read-only
- **Error handling and edge cases**

#### 2b. Verify claims before writing

For every architectural claim you plan to make:
- **Read the actual code** — don't rely on function names or comments alone
- **Trace the full data flow** — follow data from entry to exit
- **Check for side-effects** — does this function mutate state it doesn't appear to?
- **Verify conditions** — are checks read-only or do they flip flags?

**Common traps to avoid:**
- Describing a function as "activating" something when it only evaluates a condition read-only
- Showing a 3-way decision tree when the code has a 2-way branch
- Omitting persistent side-effects (e.g., a skip action that also writes to `gsu_state`)
- Mixing node registration names with Python function names

### For Prospective Docs (designing before implementation)

**Goal:** Understand the existing system deeply enough to design a change that fits.

#### 2a. Explore the integration surface

Use Explore agents to understand what the new design will touch:

- **Existing patterns**: How do similar features work today? What conventions must be followed?
- **State models**: What dataclasses, DB schemas, and config structures will the new design read or extend?
- **Entry points**: Where will the new code be called from? What interfaces must it conform to?
- **Constraints**: What can't change (shared state, public APIs, config schemas consumed by other systems)?

#### 2b. Identify reusable components

Before proposing new code, find what already exists:
- Utilities, clients, and helpers that solve part of the problem
- Config patterns that can be extended rather than duplicated
- Test fixtures and mocking patterns for the area being changed

#### 2c. Capture the "before" state

For the sections of the system being changed, document the current behavior clearly. The design doc should show the reader what exists today and what will change — the delta must be obvious.

### For Both Modes

#### 2d. Inform the user of findings

After exploration, briefly tell the user:
- Key components discovered and their relationships
- Any surprising patterns or non-obvious behaviors
- Anything that contradicts initial assumptions
- (Prospective) Existing patterns the new design should follow or reuse

---

## Phase 3: Write the Design Document

### 3a. Determine file placement

Place the doc in the most relevant `docs/` subdirectory based on the topic:

| Topic area | Path |
|------------|------|
| Onboarding / core flows | `docs/architecture/` |
| Agent behavior / routing | `docs/components/agents/` |
| Screen guidance / vision | `docs/components/` |
| API endpoints | `docs/api/` |
| Performance / latency | `docs/perf/` |
| Testing strategy | `docs/test/` |
| Feature-specific | `docs/feats/<feature-name>/` |
| IXP / experiments | `docs/features/experiments/` |
| Config / migration | `docs/config_migration/` |
| Omni integration | `docs/integrations/` |

If a subtopic warrants its own subdirectory (e.g., multi-file design with requirements + ADRs), create it. Use kebab-case for new directories.

If the directory doesn't exist, create it. Tell the user where the file is being placed and why.

### 3b. Document structure

The structure varies by mode. Include all sections that apply; omit sections that don't add value.

**Table of Contents:** Include a ToC for docs with 6+ sections. Use Markdown anchor links (`[Section Name](#section-name)`). Omit for shorter docs — the section headings are sufficient.

#### Retrospective template (documenting existing code)

```markdown
# Design Overview: <Product> — <Title>

| Role | Name |
| :---- | :---- |
| Driver | <name> |
| Approver | |
| Escalation | |
| Contributor | |
| Overall Status | Production |

**Epic:** #123
**Date:** YYYY-MM-DD
**Detailed Design:** [link if applicable]

---

## 1. Introduction

### 1.1 Purpose
What this system does, why it exists, and what problem it solves.
Lead with the core architectural insight — what makes this design non-obvious.

### 1.2 Design Principles
3-5 bold-titled principles that guided the design.
Format: **Principle name** — one-sentence explanation.

---

## 2. High-Level Architecture

### 2.1 Core Component
Mermaid diagram + prose explaining the main structural element.

### 2.2 Landscape / Scope
Table or diagram showing what's covered (modules, agents, endpoints, etc.)

### 2.3 Request Lifecycle
Mermaid sequence diagram showing a single request end-to-end.

---

## 3. Detailed Design

One subsection per major component or flow. Each subsection should have:
- A Mermaid diagram (flowchart, sequence, or both)
- Prose explaining the diagram
- Tables for structured data (config fields, state fields, actions)
- Code snippets only when showing a contract or interface (engineering audience)

**Patterns worth calling out:** If a component uses a novel or non-obvious
pattern (e.g., a completion contract, fire-and-forget with context propagation),
describe it inline within that component's subsection. Don't create a separate
"Patterns" section unless the pattern genuinely spans multiple components and
doesn't belong to any single one. Pulling patterns out of their natural context
forces the reader to jump back and forth.

---

## 4. Key Design Decisions

### 4.N Why <Decision>
**Problem**: What issue prompted this decision.
**Decision**: What was chosen.
**Reasoning** or **Evidence**: Why this option won.
**Trade-offs**: What was given up (if applicable).

---

```

#### Prospective template (designing before implementation)

```markdown
# Design Doc: <Product> — <Title>

| Role | Name |
| :---- | :---- |
| Driver | <name> |
| Approver | |
| Escalation | |
| Contributor | |
| Overall Status | Proposed / Draft |

**Epic:** #123
**Date:** YYYY-MM-DD

---

## Table of Contents
(Include for docs with 6+ sections)

---

## 1. Problem Statement

### 1.1 Symptom
What the user or system experiences today. Be specific — name the
failure modes (P1, P2, P3) with concrete examples.

### 1.2 Root Cause
Why the symptoms exist. Diagrams showing current data flow or
state model gaps are valuable here.

---

## 2. Background and Prior Art
What exists today that this design builds on or replaces.
Current architecture diagrams of the affected area.

---

## 3. Design Principles
3-5 bold-titled principles that will guide decisions.

---

## 4. Approach Alternatives

### 4.1 Option A — <Name>
How it works, pros, cons, effort estimate.

### 4.2 Option B — <Name>
How it works, pros, cons, effort estimate.

### 4.3 Comparison Matrix

| Criterion | Option A | Option B |
|-----------|----------|----------|
| Complexity | ... | ... |
| Migration risk | ... | ... |
| Future extensibility | ... | ... |

---

## 5. Recommended Approach — <Name>
Why this option was selected. Reference the comparison matrix.

---

## 6. System Diagrams
Mermaid diagrams showing the proposed architecture.
Sequence diagrams showing the new request lifecycle.
Clearly label what is NEW vs. what ALREADY EXISTS.

---

## 7. Detailed Design
Per-component breakdown. For each component:
- What changes (new code, modified code, config changes)
- Data model changes (before/after schemas)
- Integration points with existing code (file paths, function names)

---

## 8. Key Design Decisions
Same format as retrospective: Problem → Decision → Reasoning.

---

## 9. Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| ... | ... | ... | ... |

---

## 10. Open Questions
Numbered list of unresolved questions that need input.

---

```

**Choosing between templates:** Use the retrospective template when code exists. Use the prospective template when proposing changes. If the doc covers a mix (e.g., documenting an existing system and proposing an extension), use the prospective template — it's a superset.

### 3c. Mermaid diagram conventions

Use Mermaid for all diagrams unless the user explicitly requests something else (draw.io, ASCII, etc.).

**Diagram types and when to use them:**

| Type | When to use | Mermaid syntax |
|------|-------------|---------------|
| Flowchart (LR) | Component structure, graph topology | `flowchart LR` |
| Flowchart (TD) | Decision trees, branching logic | `flowchart TD` |
| Sequence diagram | Request lifecycle, multi-component interaction | `sequenceDiagram` |

**Style conventions:**
- Use `rect rgb(...)` blocks in sequence diagrams to group related steps
- Use `<br/>(annotation)` in node labels for context — avoid `<i>` tags as they don't render in all Mermaid engines; use parentheses instead for emphasis
- Use `style NodeName fill:#color` for visual grouping (green for happy path, yellow for conditional, blue for system phases)
- Keep diagrams focused — one concept per diagram. Split rather than cram.
- Edge labels should be short — use the `|"label"|` syntax
- For conditional edges, show all paths explicitly

**Node naming:**
- **Engineering audience**: Use actual code names (function names, node registration names, class names). If a node has both a registration name and a function name (e.g., LangGraph nodes), use the registration name in diagrams and note the function name in prose. Be precise — `generate_instructions` not `generate_chip_management_instructions` if that's the registered name.
- **Stakeholder audience**: Use descriptive labels that convey the role, not the implementation. E.g., "Routing Step" not `route_node`, "Execution Step" not `invoke_node`, "Start" / "End" not `__start__` / `__end__`. The reader should understand what each node does from its label alone.

### 3d. Writing style

**Accessibility first.** The audience may include staff engineers, product managers, new team members, or people unfamiliar with the repo's tech stack. Write so that someone who has never seen the codebase can follow the design.

- **Explain concepts before using them.** Don't assume the reader knows what a LangGraph `StateGraph` is, what "fire-and-forget" means, or how SSE streaming works. A one-sentence explanation on first use is enough — e.g., *"a LangGraph `StateGraph` — a directed graph where each node is an async function that transforms shared state"*.
- **Build from simple to detailed (progressive complexity).** The document should read top-to-bottom with increasing detail. Section 2 (High-Level Architecture) should give the reader a complete mental model before Section 3 (Detailed Design) adds depth. Each section should be understandable without reading later sections. Never forward-reference a concept that hasn't been introduced yet.
- **Use plain language.** Prefer "checks whether the section is completed" over "evaluates a `phase_section_completed` predicate against the materialized state projection." Technical precision comes from correct terminology, not from dense phrasing.
- **Lead with the insight, not the setup.** The first paragraph of each section should tell the reader what's interesting, not provide background.
- **Tables over prose for structured data.** Actions, fields, config options, state schemas — use tables.
- **Bold key terms** on first use. Format: `**term** — definition`.
- **Code snippets are for contracts and interfaces**, not implementation details. Show the shape of data, not the full function.
- **For stakeholder-audience docs, replace code with design-level equivalents.** Don't include function definitions, Python dicts, or JSON config blocks verbatim. Instead: replace a function's logic with a prose description of what it checks and what happens; replace a data structure with a table showing field names, descriptions, and examples; replace a config block with a table showing the rule in plain language (e.g., "Reporting requires bank connection" instead of a JSON condition object).
- **Be precise about mutations vs. reads.** If a function evaluates a condition without changing state, say "read-only" or "no state mutation". If it writes, document the side-effect.
- **Keep diagrams focused.** One concept per diagram. If a diagram needs more than ~15 nodes, split it. Add prose annotations below each diagram explaining what the reader should take away — don't rely on the diagram alone.
- **No filler.** Every sentence should add information the reader doesn't already have.

**Formatting conventions:**
- Section numbering uses escaped periods: `## 1\.`, `### 1.1` (for Google Docs / export compatibility)
- Tables use left-aligned syntax: `| :---- |`

### 3e. Cross-reference accuracy

Before finalizing:
- **Verify every file path** exists in the codebase
- **Verify function names** match current code (not stale references)
- **Verify state field names** match the actual dataclass/model definitions
- **Verify diagram claims** against actual code behavior (read-only vs. mutation, 2-way vs. 3-way branches, etc.)

---

## Phase 4: Review and Deliver

### 4a. Self-review checklist

Before presenting to the user, verify against the relevant checklist:

**Both modes:**
- [ ] Concepts are explained before they're used — a newcomer can follow the doc
- [ ] Progressive complexity — Section 2 provides a complete mental model before Section 3 adds depth
- [ ] Each section builds on the last — no forward-references to unexplained ideas
- [ ] Tables are used for structured data instead of long prose lists
- [ ] Design principles are stated upfront
- [ ] The doc answers "why" not just "what" for each design decision
- [ ] No stale file path or function name references (engineering audience)
- [ ] Diagrams have prose annotations — they don't stand alone
- [ ] Diagrams use audience-appropriate labels (descriptive for stakeholder, code names for engineering)
- [ ] Audience mode is respected — no code terminology in stakeholder docs, no over-simplification in engineering docs
- [ ] Table of Contents is included if the doc has 6+ sections

**Retrospective (documenting existing code):**
- [ ] Every diagram accurately reflects the code (no phantom function calls, correct branching)
- [ ] State mutations are documented; read-only evaluations are marked as such
- [ ] Node/function names match the codebase
- [ ] No claims about "activation" or "flag flipping" where evaluation is read-only
- [ ] Side-effects (DB writes, state mutations) are called out explicitly

**Prospective (designing before implementation):**
- [ ] The problem statement is concrete — specific failure modes, not vague goals
- [ ] The "before" state (current system) is documented clearly enough to see the delta
- [ ] The proposed design accounts for existing constraints discovered in Phase 2
- [ ] Alternatives are genuinely compared, not straw-manned
- [ ] Risks are identified with mitigations — not just optimistic paths
- [ ] Open questions are listed — nothing is silently assumed
- [ ] New vs. existing components are clearly labeled in diagrams

### 4b. Present to the user

Tell the user:
- Where the doc was created (full path)
- A brief summary of what it covers
- Any areas where you made judgment calls they should review
- Any open questions or areas that need their input

---

## Guardrails

- **Never write a design doc without exploring the relevant codebase first.** Phase 2 is mandatory — even for prospective docs, you must understand the existing system.
- **Never describe a function as doing something it doesn't.** If unsure, re-read the code.
- **Never guess at file paths.** Glob/grep to find them.
- **Never mix node registration names with function names** without explicitly noting both (engineering audience). For stakeholder audience, use neither — use descriptive role-based labels.
- **Always tell the user** where the doc is being placed and why, before writing it.
- **Always use Mermaid** for diagrams unless the user explicitly requests otherwise.
- **Never include a Key File Locations appendix.** File paths belong in the codebase, not in design docs.
- **Always run through the self-review checklist** (Phase 4a) before presenting to the user. Use the mode-specific checklist that matches the doc type.
- **Date format:** YYYY-MM-DD
- **Author:** Use `git config user.name` or ask the user.
