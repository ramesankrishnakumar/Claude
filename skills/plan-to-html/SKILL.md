---
name: plan-to-html
description: >
  Transform a Markdown plan file into a polished, self-contained HTML document
  with a synthesized hero zone (TL;DR, autonumbered Mermaid sequence diagram by
  default, "pay attention to" watch-outs) and a rendered detail zone with TOC,
  stable section IDs, and copy buttons on every code/diagram block. Trigger when
  user says: plan to html, render this plan, share this plan as html, make this
  plan presentable, /plan-to-html, or provides a path to a `.md` plan and asks
  for an HTML rendering.
user-invocable: true
---

# plan-to-html

**Goal:** Take a Markdown plan file and produce a single self-contained `.html` file next to it. The output has two zones:

- **Hero zone** — agent-synthesized: TL;DR (3–5 bullets), an approach diagram chosen by rule, and a "pay attention to" panel of watch-outs.
- **Detail zone** — mechanically rendered from the plan: full body as HTML with a TOC, stable section IDs, and copy buttons on every `<pre>` and `.mermaid-fig`.

The template (`template.html`) ships with this skill. The agent's job is to **read the plan, synthesize hero content, convert the body, and fill the template**.

---

## Usage

```
/plan-to-html <path-to-plan.md>
```

If no path is provided, ask: *"Which plan file should I render? (path to a `.md` file)"*. Do not proceed without a path.

**Callable from another skill (ad-hoc content mode).** A caller (e.g. `forge`'s `phases/_visualize.md` dispatcher) may invoke this skill with **synthesized Markdown content** instead of an on-disk path. The caller passes:

- `--content` — the full Markdown source as a string (must include a `# Title` heading and may include a ```` ```mermaid ```` block the caller has already chosen).
- `--output` *(optional)* — an explicit absolute output path. Overrides the default "next to source" rule from Phase 5.

When `--content` is supplied there is no source `.md` on disk; treat the content as the source for Phase 1. When `--output` is supplied, write there (and skip the "next to source" rule). When neither is supplied, behavior is unchanged.

---

## Phase 1 — Read the source

If invoked with a path: read the source `.md` end-to-end with the `Read` tool. Note the title (first `# ` heading), the overall structure, and the diagram needs (sequence vs flow vs lifecycle, see the diagram-choice standard below).

If invoked with `--content`: treat the supplied Markdown string as the source. Same checks apply (title, structure, diagram needs). Skip the file-exists check.

If the file doesn't exist or isn't a `.md` file (and no `--content` was passed), say so and stop.

---

## Phase 2 — Synthesize the hero zone

The hero is the executive view. Three components, all agent-generated.

### TL;DR

3–5 bullets. Each one sentence. Lead with the **insight a reviewer most needs to know**, not the bullet form of the plan's headings. If the plan is about a refactor, the TL;DR should explain what's changing *and what isn't*. If it's about a new feature, name the wedge and the user benefit.

Do not copy the plan's own bullets verbatim. Synthesize.

### Approach diagram

Pick the diagram type using this **diagram-choice standard**. Do not improvise outside it.

| Plan describes… | Use | Why |
|---|---|---|
| A request flow with multiple components passing messages (sync or async) — **default** | `sequenceDiagram` with `autonumber` | Numbered steps; clear actor lanes; supports `-->>` returns and `-)` async fire-and-forget; `activate`/`deactivate` shows concurrent work |
| A pipeline / data transformation with branches, no actor lanes | `flowchart LR` | Linear story |
| A lifecycle with named states and transitions | `stateDiagram-v2` | States are nouns, transitions verbs |
| Layered architecture / "which layer owns what" | `block-beta` | Shows containment, not flow |
| Decision tree | `flowchart TD` | Branches read top-down |

**Default if ambiguous:** `sequenceDiagram` with `autonumber`.

**Caller-supplied Mermaid takes precedence.** If the input already contains a ```` ```mermaid ```` block (typically because the caller — e.g. `forge`'s `_visualize.md` — has already chosen the diagram type for its audience), use that block as-is. Do not re-pick the type. The table above only governs standalone invocations where no diagram is present in the source.

**Mermaid conventions:**
- Always include `autonumber` for sequence diagrams.
- Use `->>` for sync calls, `-->>` for returns, `-)` for async fire-and-forget, `activate`/`deactivate` to show concurrent work, `opt`/`alt`/`par` for branches and parallelism. `par` blocks **require a label on the same line** (e.g., `par Issues and Build in parallel`), and `and` separates branches.
- Use **descriptive role labels** for participants — match the names used in the plan (e.g., `intent_orchestrator`, not `IO`, unless you also keep the long form as a label).
- **Do not** set node colors or fills inline — the template ships themed `themeVariables` that the agent must not override.
- Emit clean Mermaid source — no leading indentation inside the `{{approach_diagram}}` placeholder.

**Character hygiene (verified against Mermaid 11.15 — the version this skill pins).** Mermaid's sequence-diagram parser rejects several characters that look fine in prose. If you include any of these in participant declarations or message labels, the diagram renders as *"Syntax error in text"*:

- **`<br/>` inside `participant` lines.** Allowed in messages, rejected in `participant X as ...` declarations. Put parenthetical context in the alias on a single line, or move it to the figure caption.
- **Raw `<` and `>` in messages or aliases** (e.g. `<description>`, `<url>`). Reword without angle brackets, or use a literal word like `description`.
- **Raw `{` and `}` in messages** (e.g. `{phase: ok, files: [...]}`). Mermaid treats braces as DSL. Use commas or parens instead: `phase ok, files listed`.
- **`[` `]` in messages** (e.g. `[...]`, `[slug]`). Same reason — flatten to prose.

Safe in messages: letters, digits, spaces, `,` `.` `_` `-` `(` `)` `+` `=` `:` (when not adjacent to braces), and the arrow operators themselves. When in doubt, rewrite the label as a short prose phrase — a simpler diagram that renders beats a clever one that doesn't.

If the plan genuinely has no flow to diagram (rare — usually a pure config change), set `{{approach_empty_class}}` to ` empty` so the figure hides, and skip the diagram.

### Watch-outs ("pay attention to")

2–4 items. Each must name something a reviewer would regret missing — irreversible steps, dependencies between PRs, untested surfaces, deprecated code left in, schema migrations, etc. Each watch-out gets:

- A short title (the headline).
- A 1–2 sentence body explaining the risk.
- A type-prefixed ID: `note-watch-out-<slug>`.

If you genuinely can't find any watch-outs, set `{{watch_empty_class}}` to ` empty` so the panel hides.

---

## Phase 3 — Convert the plan body to HTML (inline, no external toolchain)

Walk the Markdown and emit HTML for the detail zone. **The agent does this conversion — no pandoc, no remark, no JS toolchain.**

### Deterministic slugifier

Use this rule everywhere an ID is generated:

1. Lowercase the source text.
2. Replace every run of non-`[a-z0-9]` characters with a single `-`.
3. Strip leading and trailing `-`.
4. If empty, fall back to a positional name (e.g., `code-1`) — but only if the source text has *no* alphanumerics at all.

**ID prefixes by element type:**
- Headings: `section-<slug>`
- Mermaid blocks: `fig-<slug-of-caption-or-first-line>`
- Code blocks: `code-<slug-of-first-meaningful-token>` (or `code-1`, `code-2` only if nothing better)
- Tables: `tbl-<slug-of-first-header-cell>`
- Decision items (numbered list items under a `Decisions` heading): `decision-<slug>`
- Watch-out items (hero panel): `note-watch-out-<slug>`

IDs MUST be deterministic. Running the skill twice on the same input produces byte-identical IDs.

### Element mapping

| Markdown | HTML |
|---|---|
| `# Title` | Used as `{{title}}` and `{{eyebrow}}` (eyebrow = "Plan · …" derived). Not emitted in the body. |
| `## Section` | `<h2 id="section-...">Section <span class="id-chip" data-copy="section-...">section-...</span></h2>` |
| `### Sub` | `<h3 id="section-...">Sub <span class="id-chip" ...>section-...</span></h3>` |
| `**bold**`, `*italic*`, `` `code` ``, `[link](url)` | Standard `<strong>`, `<em>`, `<code>`, `<a>` |
| Bullet / numbered list | `<ul>` / `<ol>` |
| Numbered list under `## Decisions` / `## Key Decisions` | Each `<li>` gets `id="decision-<slug>"` and a trailing `<span class="id-chip" data-copy="decision-...">decision-...</span>` |
| Task list (`- [ ]`) | `<li><input type="checkbox" disabled> …</li>` |
| Table | `<div class="table-wrap" id="tbl-...">…<table>…</table></div>` with an ID chip in a toolbar above the table |
| ```` ```mermaid ```` block | `<figure class="mermaid-fig" id="fig-..."><div class="toolbar">…id-chip + copy-PNG button…</div><div class="mermaid">…raw mermaid source…</div></figure>`. Optionally a `<figcaption>` if the line above the block is a caption-like sentence. |
| Other fenced block (```` ```json ````, ```` ```python ````, etc.) | `<div class="code-wrap" id="code-..."><div class="code-toolbar"><span class="id-chip">code-...</span><button class="icon-btn copy-code">copy</button></div><pre><code class="language-XXX">…escaped content…</code></pre></div> |
| Plain paragraph | `<p>…</p>` |
| `---` horizontal rule | Omit (the template uses section borders for separation). |

**HTML-escape** the content inside `<pre><code>` — `<`, `>`, `&`. Do not escape inside the `<div class="mermaid">` block; Mermaid parses raw text.

### Build the TOC

Collect every `## ` and `### ` heading you emitted, in order. Output to `{{toc}}` as:

```html
<li class="depth-2"><a href="#section-...">Section title</a></li>
<li class="depth-3"><a href="#section-...">Sub title</a></li>
```

---

## Phase 4 — Fill the template

Read `template.html` (sibling to this `SKILL.md`). Replace placeholders:

| Placeholder | Value |
|---|---|
| `{{title}}` | The plan's `# ` heading text |
| `{{eyebrow}}` | A short kicker like `Plan · <topic>` — derive from the title (strip the leading "Plan:" if present, take the first 4–6 words of remainder) |
| `{{subtitle}}` | One sentence summarizing the change — synthesize from the plan's opening paragraph or Problem section |
| `{{tldr}}` | TL;DR `<li>…</li>` lines, indented 12 spaces |
| `{{tldr_empty_class}}` | Empty string `""`, or ` empty` if the list is empty |
| `{{watch_out}}` | Watch-out `<li id="note-watch-out-..."><div class="watch-title">…<span class="id-chip">…</span></div><p class="watch-body">…</p></li>` items |
| `{{watch_empty_class}}` | `""` or ` empty` |
| `{{approach_title}}` | Short label for the diagram, e.g. `Turn lifecycle`, `Migration sequence`, `Decision flow` |
| `{{approach_diagram}}` | The raw Mermaid source — no surrounding ```` ``` ```` fences |
| `{{approach_caption}}` | One sentence explaining what the diagram shows |
| `{{approach_empty_class}}` | `""` or ` empty` |
| `{{toc}}` | TOC `<li>` lines |
| `{{detail_body}}` | All converted body HTML — every `<h2>`, `<h3>`, list, code block, table, mermaid figure, paragraph, in source order |
| `{{source_basename}}` | The source file's basename (e.g. `guided-setup-slim-lvl2.md`) |

---

## Phase 5 — Write the output

Resolve the output path:
- If the caller passed `--output`, use it verbatim.
- Else, if invoked with a path, write to `<source-basename>.html` in the **same directory** as the source `.md`.
- Else (ad-hoc `--content` with no `--output`), the caller must supply `--output` — error if missing.

**Auto-open after writing.** Run `open "<output-path>"` via the `Bash` tool (macOS). If the `open` command fails or the platform isn't macOS, soft-fail: tell the user the render path so they can open it manually. Never error the whole flow on a failed auto-open.

Tell the user:
- The output path.
- That the file is now open (or, on soft-fail, that they can `open` it manually — the file is self-contained).
- A one-line summary: TL;DR bullet count, diagram type chosen, number of watch-outs.
- **Section markers for follow-up.** Mention as a hint: *"You can reference any `section-…`, `fig-…`, `decision-…`, or `note-watch-out-…` ID from the HTML in your follow-up — I'll answer from the source Markdown."*

---

## Guardrails

- **Single file out.** No sidecar CSS or JS. The template inlines everything except the Mermaid CDN.
- **Output is next to the source by default**, unless the caller passes `--output`. Never write to `docs/`, `~/Desktop`, or elsewhere on a default standalone invocation.
- **HTML is human-only and one-way.** Callers (including the agent itself) must never read this HTML back as input to a future decision. Always re-derive from the source Markdown. The HTML exists so the human can scan and quote section IDs; it is not an agent contract.
- **Deterministic IDs.** Two runs on the same input must produce byte-identical IDs. Test this if you change the slugifier.
- **Don't override the Mermaid theme.** The template sets `themeVariables`; agent-emitted diagrams must not include `%%{ init: {...} }%%` blocks.
- **Don't escape inside mermaid blocks.** HTML-escape only inside `<pre><code>`. Mermaid expects raw `<br/>`, `<`, `>` in its own syntax.
- **Hero is synthesized, not copied.** Even if the plan has a `## TL;DR` section, regenerate. The hero is the agent's reading of the plan.
- **Watch-outs require evidence in the plan.** Don't invent risks. If the plan doesn't surface anything risky, hide the panel.
- **Pandoc is forbidden.** This is intentional — no external toolchain.

---

## Reference example

See `examples/guided-setup-slim-lvl2.html` for the canonical reference output. When in doubt about layout, spacing, or markup, mirror that file.
