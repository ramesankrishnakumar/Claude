---
name: google-docs
description: Create, read, append, replace content, and insert images in Google Docs. Converts Markdown to native Docs formatting including headings, lists, tables, links, and code blocks. Includes a canonical style table and content mapper for visually consistent, design-quality documents. Use when the user asks to create a Google Doc, read a doc, edit a doc, insert images, convert markdown to Google Docs, or references a docs.google.com URL.
---

# Google Docs

## Prerequisites

**CLI:** `gws` (Google Workspace CLI) — handles authentication automatically via keyring.

**Auth setup** (one-time, or when session expires):

```bash
gcloud auth login
```

This is all that's needed. `gws` picks up the credentials automatically. If you see 401/403 errors, re-run this command.

For a custom Google Cloud project: `gcloud auth login`, enable Docs and Drive APIs, then `gws auth setup` and `gws auth login` (https://github.com/googleworkspace/cli).

## Scripts

Scripts location: `~/.claude/skills/google-docs/scripts/`

Document IDs are extracted automatically from URLs: `docs.google.com/document/d/DOC_ID/edit`

| Operation | Command |
|-----------|---------|
| Create (plain) | `scripts/create_doc.sh "Title" "Content"` |
| Create (markdown) | `scripts/create_doc.sh "Title" "# Heading" --markdown` |
| Create from file | `scripts/create_from_markdown.sh "Title" --file doc.md` |
| Read | `scripts/read_doc.sh DOC_ID` |
| Append | `scripts/append_doc.sh DOC_ID "Text"` |
| Replace | `scripts/replace_doc.sh DOC_ID "Content"` |
| Insert image | `scripts/insert_image.sh DOC_ID IMAGE_URL [--width W] [--index N]` |
| Format | `scripts/format_doc.sh DOC_ID [--mode fresh-doc\|template-aware]` |
| Info | `scripts/doc_info.sh DOC_ID` |

## Markdown Support

Use `--markdown` flag or `create_from_markdown.sh` for proper formatting:

```bash
scripts/create_from_markdown.sh "Report" --file report.md
echo "# Hello World" | scripts/create_from_markdown.sh "Test"
```

Supported: headings, lists, tables, links, bold/italic, code blocks, horizontal rules.

## Insert Images

Images must be publicly accessible URLs. For Drive images, share publicly first.

```bash
scripts/insert_image.sh DOC_ID "https://..." --width 500
```

**Note:** Corporate policies may block public sharing. See [image-workflow.md](image-workflow.md) for workarounds.

## Format Existing Documents

Apply the Canonical Style Table to an existing Google Doc in-place. Styles headings, body text, tables, code blocks, bullet lists, and bold labels without modifying content.

```bash
scripts/format_doc.sh DOC_ID                              # Full canonical styling
scripts/format_doc.sh DOC_ID --mode template-aware         # Preserve template fonts/colors
scripts/format_doc.sh DOC_ID --dry-run                     # Preview without applying
scripts/format_doc.sh DOC_ID --config patterns.json        # Custom detection patterns
```

**Safety:** Never inserts or deletes content. Preserves all links, images, and tables. Verifies integrity before and after.

**Modes:**
- `fresh-doc` (default) — Full Canonical Style Table: fonts, sizes, colors, spacing on every paragraph
- `template-aware` — Only sets heading types. Preserves template fonts/colors. Still applies table structure and code shading.

**Custom config** (JSON, all fields optional) overrides detection heuristics for code blocks, bullets, and bold labels. See `format_doc.sh --help` for the config format.

## Additional Resources

- Image embedding workflow: [image-workflow.md](image-workflow.md)
- API reference and batch requests: [api-reference.md](api-reference.md)
- Auth troubleshooting: [troubleshooting.md](troubleshooting.md)
- Google Cloud: user-owned project with Docs + Drive APIs enabled

---

# Design Formatting

This section provides the canonical formatting rules for producing visually consistent, design-quality Google Docs. It applies to all write and edit operations.

## Pre-Step Protocol

Before writing content to any Google Doc, complete these three steps:

**Step 1 — Mode:** Determine the document mode.

| Mode | When to Use | Behavior |
|---|---|---|
| **`fresh-doc`** (default) | Creating a new doc, or full control over styling is needed | Apply the Canonical Style Table in full — every paragraph gets `namedStyleType` + all explicit overrides |
| **`template-aware`** | Editing a doc that already has a company/brand template applied, and the user wants to preserve its look | Only set `namedStyleType` — no explicit style overrides. Respect inherited template styles |

If unsure, use **`fresh-doc`**.

**Step 2 — Internalize:** Read and absorb the Canonical Style Table, Content Type Guidelines, and API Mechanics Reference below.

**Step 3 — Map:** Run the Content Mapper on every piece of content the user wants to create or edit. Output the mapping explicitly (e.g., "Title -> TITLE, intro sentence -> Paragraph, items -> Numbered List") before issuing any API calls.

Only after all three steps are complete may you begin constructing `batchUpdate` requests.

---

## Canonical Style Table

These are the exact values to apply on every paragraph in `fresh-doc` mode. The "Anchor + Full Override" pattern means: always set `namedStyleType` (semantic anchor) AND always set every explicit property listed (visual determinism).

### Text Styles (updateTextStyle)

| Content Type | Font Family | Font Size | Bold | Italic | Color (RGB normalized) | Other |
|---|---|---|---|---|---|---|
| **Title** | Arial | 24pt | true | false | `r=0.1, g=0.1, b=0.18` (#1a1a2e) | — |
| **Subtitle** | Arial | 13pt | false | true | `r=0.4, g=0.4, b=0.4` (#666666) | — |
| **Heading 1** | Arial | 20pt | true | false | `r=0.1, g=0.1, b=0.18` (#1a1a2e) | — |
| **Heading 2** | Arial | 16pt | true | false | `r=0.2, g=0.2, b=0.2` (#333333) | — |
| **Heading 3** | Arial | 13pt | true | false | `r=0.33, g=0.33, b=0.33` (#555555) | — |
| **Heading 4** | Arial | 11pt | true | false | `r=0.33, g=0.33, b=0.33` (#555555) | — |
| **Heading 5** | Arial | 11pt | true | true | `r=0.4, g=0.4, b=0.4` (#666666) | — |
| **Heading 6** | Arial | 10pt | true | true | `r=0.4, g=0.4, b=0.4` (#666666) | — |
| **Paragraph** | Arial | 11pt | false | false | `r=0.13, g=0.13, b=0.13` (#222222) | — |
| **Bold Label** | Arial | 11pt | true (label), false (value) | false | `r=0.13, g=0.13, b=0.13` (#222222) | Bold on label span only |
| **Bullet List Item** | Arial | 11pt | false | false | `r=0.13, g=0.13, b=0.13` (#222222) | — |
| **Numbered List Item** | Arial | 11pt | false | false | `r=0.13, g=0.13, b=0.13` (#222222) | — |
| **Code Block** | Roboto Mono | 9pt | false | false | `r=0.094, g=0.502, b=0.220` (#18803a) | — |
| **Inline Code** | Courier New | 10pt | false | false | `r=0.13, g=0.13, b=0.13` (#222222) | backgroundColor: `r=0.95, g=0.95, b=0.95` (#f2f2f2) |
| **Highlighted Subtitle** | Arial | 11pt | true | true | `r=0.13, g=0.13, b=0.13` (#222222) | backgroundColor: `r=1, g=0.95, b=0.6` (#fff299) |
| **Hyperlink** | Arial | 11pt | false | false | `r=0.067, g=0.333, b=0.8` (#1155cc) | underline=true, link.url=`<url>` |
| **Callout Box** | Arial | 11pt | false | false | `r=0.13, g=0.13, b=0.13` (#222222) | See Callout Box section |
| **Image Caption** | Arial | 9pt | false | true | `r=0.4, g=0.4, b=0.4` (#666666) | alignment: CENTER |

### Paragraph Styles (updateParagraphStyle)

| Content Type | `namedStyleType` | Alignment | spaceAbove (PT) | spaceBelow (PT) | lineSpacing | Other |
|---|---|---|---|---|---|---|
| **Title** | `TITLE` | START | 0 | 3 | 115 | — |
| **Subtitle** | `SUBTITLE` | START | 0 | 14 | 115 | — |
| **Heading 1** | `HEADING_1` | START | 20 | 8 | 115 | keepWithNext=true |
| **Heading 2** | `HEADING_2` | START | 18 | 6 | 115 | keepWithNext=true |
| **Heading 3** | `HEADING_3` | START | 14 | 4 | 115 | keepWithNext=true |
| **Heading 4** | `HEADING_4` | START | 12 | 4 | 115 | keepWithNext=true |
| **Heading 5** | `HEADING_5` | START | 10 | 4 | 115 | keepWithNext=true |
| **Heading 6** | `HEADING_6` | START | 10 | 4 | 115 | keepWithNext=true |
| **Paragraph** | `NORMAL_TEXT` | START | 0 | 6 | 115 | — |
| **Bold Label** | `NORMAL_TEXT` | START | 0 | 6 | 115 | — |
| **Bullet List Item** | `NORMAL_TEXT` | START | 0 | 2 | 115 | + `createParagraphBullets` BULLET_DISC_CIRCLE_SQUARE |
| **Numbered List Item** | `NORMAL_TEXT` | START | 0 | 2 | 115 | + `createParagraphBullets` NUMBERED_DECIMAL_ALPHA_ROMAN |
| **Code Block content** | `NORMAL_TEXT` | START | 0 | 0 | 115 | shading.backgroundColor: `r=0.94, g=0.94, b=0.94` (#efefef), indentStart=18pt, indentEnd=18pt, spacingMode=COLLAPSE_LISTS |
| **Code Block fence** | `NORMAL_TEXT` | START | 0 | 0 | 100 | Same shading + indent as content |
| **Code Block spacing** | `NORMAL_TEXT` | START | 0 | 0 | 100 | No shading, no indent — breathing room |
| **Horizontal Rule** | `NORMAL_TEXT` | START | 12 | 12 | 100 | borderBottom: solid, 1pt, `r=0.8, g=0.8, b=0.8` (#cccccc) |
| **Highlighted Subtitle** | `NORMAL_TEXT` | START | 6 | 6 | 115 | — |
| **Hyperlink** | `NORMAL_TEXT` | START | 0 | 6 | 115 | — (inline within paragraph) |
| **Page Break** | `NORMAL_TEXT` | START | 0 | 0 | 100 | pageBreakBefore=true |
| **Image Caption** | `NORMAL_TEXT` | CENTER | 0 | 12 | 115 | — |
| **Callout Box** | — | — | — | — | — | See Callout Box section below |

### Range Grouping Rule

For 3+ consecutive paragraphs with the **same content type**, use a single `updateParagraphStyle` and/or `updateTextStyle` spanning the combined range rather than one call per paragraph.

---

## Content Type Guidelines

Every piece of content must be assigned one of the following types. Each type has a precise API implementation.

### Title

Document cover title. Used once, at the very top.

```
insertText + updateParagraphStyle (TITLE + overrides) + updateTextStyle (Arial 24pt bold)
```

### Subtitle

Document cover subtitle, directly after the Title. Used at most once.

```
insertText + updateParagraphStyle (SUBTITLE + overrides) + updateTextStyle (Arial 13pt italic gray)
```

### Heading 1–6

Section headings at progressive depth. Use H1 sparingly — for major document divisions.

```
insertText + updateParagraphStyle (HEADING_N + overrides) + updateTextStyle (per style table)
```

### Paragraph

Body prose. Default content type.

```
insertText + updateParagraphStyle (NORMAL_TEXT + overrides) + updateTextStyle (Arial 11pt)
```

### Bold Label

Label + value on the same line (e.g., "Author: Ido Dor", "Status: Draft").

```
insertText (full line) + updateParagraphStyle (NORMAL_TEXT + overrides)
+ updateTextStyle bold=true on label span only
+ updateTextStyle bold=false on value span
```

### Bullet List Item

Unordered list items.

```
insertText for all items (each ending with \n)
+ updateParagraphStyle (NORMAL_TEXT + overrides) on full range
+ updateTextStyle (Arial 11pt) on full range
+ createParagraphBullets (bulletPreset=BULLET_DISC_CIRCLE_SQUARE) on full range
```

### Numbered List Item

Ordered/sequential list items.

```
insertText for all items (each ending with \n)
+ updateParagraphStyle (NORMAL_TEXT + overrides) on full range
+ updateTextStyle (Arial 11pt) on full range
+ createParagraphBullets (bulletPreset=NUMBERED_DECIMAL_ALPHA_ROMAN) on full range
```

### Nested List Item

Indented sub-items under a parent bullet or numbered item.

```
1. insertText for all items (parent + child, each ending with \n)
2. createParagraphBullets on the FULL range (all items) with the desired preset
3. Apply indentation overrides on child items:
   - Level 1 children: indentStart=36pt, indentFirstLine=18pt
   - Level 2 children: indentStart=54pt, indentFirstLine=36pt
   Use updateParagraphStyle with fields: "indentStart,indentFirstLine"
   (do NOT use fields: "*" here — it would reset bullet formatting)
```

**Important:** The `nestingLevel` parameter in `createParagraphBullets` is unreliable. Use explicit `indentStart`/`indentFirstLine` overrides instead.

### Code Block

Multi-line code, config, commands, or technical text. Always 5 paragraphs:

1. **Pre-spacing**: plain empty `\n` paragraph — NORMAL_TEXT, no shading
2. **Open fence**: `\n` paragraph with code block paragraph style (gray shading, indent)
3. **Content line(s)**: one paragraph per line — code block paragraph style + Roboto Mono 9pt green text style
4. **Close fence**: `\n` paragraph with code block paragraph style (gray shading, indent)
5. **Post-spacing**: plain empty `\n` paragraph — NORMAL_TEXT, no shading

Paragraphs 2-4 share the same `updateParagraphStyle`. Only paragraph 3 (content) gets `updateTextStyle` with Roboto Mono + green. Paragraphs 1 and 5 are unstyled breathing room.

**Critical:** The native Google Docs code block smart chip (`\ue907`) cannot be created via the REST API — the character is silently dropped. Use the shading approach above.

### Inline Code

Short technical term, path, or command embedded in prose.

```
Applied as a text style span within a Paragraph:
updateTextStyle on the inline code span:
  weightedFontFamily=Courier New, fontSize=10pt, backgroundColor=#f2f2f2
```

### Table

Structured data with 2+ attributes per item. Full API sequence:

```
1. insertTable (rows=N, columns=M, location=insertIndex)
2. Re-read document to get actual cell startIndex values
3. updateTableColumnProperties for each column:
   - columnWidths in PT, must sum to ~451pt (for default margins)
4. Insert cell text bottom-up: last row last col -> first row first col
5. Style header row:
   - updateTextStyle: bold=true, foregroundColor=#ffffff (white)
   - updateTableCellStyle on each header cell:
     backgroundColor: r=0.26, g=0.26, b=0.26 (#424242)
     paddingTop/Bottom: 4pt, paddingLeft/Right: 6pt
6. Style data rows:
   - updateTextStyle: Arial 10pt, foregroundColor=#222222
   - updateTableCellStyle on each data cell:
     paddingTop/Bottom: 3pt, paddingLeft/Right: 6pt
     borderBottom: solid, 0.5pt, r=0.87, g=0.87, b=0.87 (#dedede)
7. Optional: alternating row background
   - Even rows: backgroundColor: r=0.97, g=0.97, b=0.97 (#f7f7f7)
   - Odd rows: no background (white)
```

### Horizontal Rule

Visual separator between major sections.

```
insertText (\n) + updateParagraphStyle:
  namedStyleType: NORMAL_TEXT
  spaceAbove: 12pt, spaceBelow: 12pt
  borderBottom: { style: SOLID, width: { magnitude: 1, unit: PT },
    color: { color: { rgbColor: { red: 0.8, green: 0.8, blue: 0.8 } } } }
```

### Highlighted Subtitle

Special notice, status, or callout (e.g., "Not Yet Reviewed", "Draft — Do Not Distribute").

```
insertText + updateParagraphStyle (NORMAL_TEXT + overrides)
+ updateTextStyle: bold=true, italic=true, backgroundColor=#fff299
```

### Hyperlink

Clickable URL or reference, applied as a span within a paragraph.

```
updateTextStyle on the link span:
  foregroundColor=#1155cc, underline=true, link.url=<url>
```

### Page Break

Forces content to start on a new page.

```
insertText (\n) + updateParagraphStyle:
  namedStyleType: NORMAL_TEXT
  pageBreakBefore: true
```

### Image (Inline)

An image inserted from a public URL.

```
1. insertInlineImage:
   uri: <publicly accessible URL>
   objectSize: height/width in PT
   location: { index: <insertIndex> }
2. Follow with a caption paragraph:
   insertText (caption text) + updateParagraphStyle (NORMAL_TEXT, alignment: CENTER)
   + updateTextStyle (Arial 9pt italic gray)
```

**Image insertion limitation:** `insertInlineImage` requires a truly publicly accessible URL. Google's servers fetch images anonymously. Google Drive URLs do NOT work. When corporate policies block public sharing, use image placeholders:

```
1. Insert styled placeholder: "[Insert image: <description>]"
   Style: Highlighted Subtitle — Arial 11pt, bold=true, italic=true,
   backgroundColor=#fff299, centered
2. Insert caption: "Figure N: <caption text>" — Arial 9pt, italic, gray, centered
3. Instruct the user to manually paste their image at the placeholder
```

### Callout Box

A visually distinct box for tips, warnings, notes. Implemented as a 1-row, 1-column table with colored background.

```
1. insertTable (rows=1, columns=1, location=insertIndex)
2. Re-read document for cell startIndex
3. Insert callout text
4. Style the cell:
   updateTableCellStyle:
     backgroundColor (by type):
       Info/Note:    r=0.91, g=0.95, b=1.0  (#e8f0fe) — light blue
       Warning:      r=1.0, g=0.96, b=0.89  (#fff4e3) — light amber
       Tip/Success:  r=0.91, g=0.98, b=0.91 (#e8fae8) — light green
       Danger/Error: r=1.0, g=0.91, b=0.91  (#ffe8e8) — light red
     paddingTop/Bottom: 8pt, paddingLeft/Right: 10pt
     borderTop/Bottom/Left/Right: solid, 0.5pt, matching accent color
5. Style the text: Arial 11pt, foregroundColor=#222222
6. Optional: bold the first word (e.g., "Note:", "Warning:", "Tip:")
```

---

## API Mechanics Reference

These rules are non-negotiable. Violating them causes index corruption, silent drops, or malformed output.

### Index Management
- **Always work bottom-up** when inserting multiple text blocks. Insert the last piece first, then work toward the front. This prevents earlier insertions from shifting the indices of later ones.
- After every `insertTable`, **re-read the document** to get actual cell start indices. Table cell indices are not predictable from the insertion point alone.
- The final character in a document body is always a non-deletable `\n`. The last valid insert index is `endIndex - 1`.

### Insert Order (Anchor + Full Override)

Always follow this sequence per element:
1. `insertText` — place the raw text
2. `updateParagraphStyle` — set `namedStyleType` AND all explicit paragraph overrides from the Canonical Style Table
3. `updateTextStyle` — set ALL explicit text overrides from the Canonical Style Table
4. `createParagraphBullets` — only after text is inserted, for list items

**In `fresh-doc` mode:** Steps 2 and 3 always include the full property set from the style table. Use `fields: "*"` to ensure no inherited properties leak through. **Exception:** If the text range contains a hyperlink (`link.url`), do NOT use `fields: "*"` on `updateTextStyle` — it will clear the link. Instead, list specific fields and apply link styling in a separate `updateTextStyle` call with `fields: "foregroundColor,underline,link"`.

**In `template-aware` mode:** Step 2 only sets `namedStyleType`. Step 3 is skipped. Step 4 still applies for list items.

### Multi-Tab Documents
When a document has multiple tabs, every `range` in every request **must** include `tabId`. Omitting it targets the wrong tab silently.

---

## Edit Operations (Modifying Existing Content)

When editing content in the middle of an existing document:

```
1. READ  — documents.get() to get current document structure
2. SEARCH — iterate body.content to find the target paragraph by text content
3. DELETE — deleteContentRange on the target paragraph's startIndex..endIndex
4. INSERT — insertText at the old startIndex with new content
5. RESTYLE — updateParagraphStyle + updateTextStyle on the new range
6. VERIFY — re-read document if subsequent edits depend on updated indices
```

**Critical rules:**
- Always re-read between structural edits — all indices shift after delete + insert.
- Delete before insert at the same position.
- Replacing a paragraph with a different content type: delete old, insert new structure, style all new paragraphs, re-read for accurate indices.

---

## Content Mapper

Run this algorithm on every piece of content before writing. Output the mapping explicitly.

### Decision Rules (apply in order)

```
1.  Document's main name/subject on the cover?           -> Title (once)
2.  Tagline/description right after the title?            -> Subtitle (once)
3.  Major document division heading?                      -> Heading 1 (sparingly)
4.  Top-level section header?                             -> Heading 2
5.  Subsection (e.g., "3.2 Entry Point Design")?          -> Heading 3
6.  Sub-subsection (fourth level or deeper)?              -> Heading 4/5/6
7.  Label + value on same line ("Author: Name")?          -> Bold Label
8.  Unordered list of items?                              -> Bullet List
9.  Ordered steps or ranked items?                        -> Numbered List
10. Nested items under a parent list item?                -> Nested List Item
11. Multi-line code, config, or technical text?           -> Code Block (5-paragraph)
12. Short technical term/path embedded in prose?          -> Inline Code
13. Structured data with 2+ attributes per item?         -> Table
14. Visual separator between major sections?              -> Horizontal Rule
15. Warning, tip, note, or important callout (boxed)?     -> Callout Box
16. Special notice or status label (not boxed)?           -> Highlighted Subtitle
17. URL or reference that should be clickable?            -> Hyperlink
18. Next content should start on a new page?              -> Page Break
19. Image or diagram to display?                          -> Image
20. Everything else?                                      -> Paragraph
```

### Opinionated Defaults

When intent is ambiguous:

- **One Title per document** — use Heading 1 for subsequent major divisions
- **Subtitle only after Title** — no title, no subtitle
- **Unordered collection** -> Bullet List (not numbered)
- **Ordered/sequential** -> Numbered List
- **2+ lines of code** -> Code Block (not inline)
- **Single word/path inline** -> Inline Code
- **2+ attributes per item** -> Table
- **Topic change between sections** -> Horizontal Rule before next Heading 2
- **Subsection numbering** -> always carry parent number ("3.2 Creating Plans")
- **Warning/Tip/Note** -> Callout Box (not Highlighted Subtitle)
- **Brief status/label** -> Highlighted Subtitle (not Callout Box)
- **All headings** -> keepWithNext=true

---

## Common Mistakes to Avoid

1. **Never rely on inherited styles** — In `fresh-doc` mode, always apply the full Canonical Style Table. Use `fields: "*"` except when the range contains a hyperlink.
2. **Never use TITLE more than once** — Use HEADING_1 for major sections after the title.
3. **Never skip paragraph spacing** — Always set `spaceAbove` and `spaceBelow`.
4. **Table column widths must sum to ~451pt** — usable width for default margins.
5. **Images require public URLs** — Google Drive private links fail silently.
6. **Nested lists need separate `createParagraphBullets` calls per level.**
7. **Always re-read after `insertTable`** — cell indices are never predictable.
8. **Code block smart chip is impossible** — `\ue907` is silently dropped. Use 5-paragraph shading.
9. **Don't forget the final `\n`** — last valid insert index is `endIndex - 1`.
10. **Header/footer sections use separate range indices** — don't mix with body indices.

---

## API Access: gws CLI vs. MCP Convenience Tools

### gws CLI (Recommended for full visual fidelity)

The `gws` CLI provides direct access to the Google Docs and Drive REST APIs with automatic authentication. Use it for `batchUpdate` requests that apply the Canonical Style Table.

```bash
# Get document
gws docs documents get --params '{"documentId":"DOC_ID"}'

# Batch update (insert, style, format)
gws docs documents batchUpdate \
  --params '{"documentId":"DOC_ID"}' \
  --json '{"requests":[...]}'

# Create document
gws docs documents create --json '{"title":"My Doc"}'

# Create from Markdown (Drive API multipart upload)
gws drive files create \
  --params '{"fields":"id,name,webViewLink"}' \
  --json '{"name":"Title","mimeType":"application/vnd.google-apps.document"}' \
  --upload file.md --upload-content-type text/markdown
```

**Note:** `gws --upload` requires the file to be under the current working directory. Scripts handle this by writing temp files to cwd when needed.

### MCP Convenience Tools (Quick operations only)

The `google-drive-mcp` provides high-level tools (`format_text`, `insert_heading`, `insert_table`, `insert_link`, `write_document`). These are useful for quick operations but **cannot execute the Canonical Style Table**:

- `format_text` only supports bold, italic, underline — no font family, font size, colors, or spacing
- `insert_heading` sets `namedStyleType` only — no explicit overrides
- `insert_table` creates empty structure — no cell styling, borders, or column widths
- `write_document` inserts plain text — no formatting

Use MCP convenience tools only for: quick prototyping, simple text appends, or when visual polish is not required.

---

## Quick Reference

```
TITLE       -> Document cover title (once)
SUBTITLE    -> Document cover subtitle (once, after title)
HEADING_1   -> Major document division
HEADING_2   -> Section title
HEADING_3   -> Subsection title (X.Y)
HEADING_4/5/6 -> Deep sub-sections
NORMAL_TEXT -> Paragraph, labels, inline elements
+ shading   -> Code block (5 paragraphs: spacing/fence/content/fence/spacing)
+ bullet    -> List item (bullet or numbered, with optional nesting)
insertTable -> Structured data (with column widths, header bg, row borders)
insertTable 1x1 -> Callout box (colored background)
borderBottom-> Horizontal rule separator
bold+italic+tinted bg -> Highlighted subtitle/callout label
blue underline + link -> Hyperlink
insertInlineImage -> Image (public URL + width + height + caption)
pageBreakBefore -> Page break
```
