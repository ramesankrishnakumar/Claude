#!/usr/bin/env python3
"""
Google Docs Canonical Style Table formatter.

Applies the Canonical Style Table (defined in SKILL.md) to an existing
Google Doc in-place. Never inserts or deletes content — only applies
updateParagraphStyle, updateTextStyle, updateTableCellStyle, and
createParagraphBullets to existing ranges.

Preserves all links, images, and table content.

Usage:
    python3 format_doc.py DOC_ID [--mode fresh-doc|template-aware]
                                 [--batch-size N] [--config PATH] [--dry-run]
"""
import argparse
import json
import re
import subprocess
import sys

# ── Color Constants (Canonical Style Table) ───────────────────────
DARK = {"red": 0.1, "green": 0.1, "blue": 0.18}          # #1a1a2e — Title, H1
BODY = {"red": 0.13, "green": 0.13, "blue": 0.13}         # #222222 — Paragraph
H2_COLOR = {"red": 0.2, "green": 0.2, "blue": 0.2}        # #333333
H3_COLOR = {"red": 0.33, "green": 0.33, "blue": 0.33}      # #555555
H4_COLOR = {"red": 0.33, "green": 0.33, "blue": 0.33}      # #555555
GRAY = {"red": 0.4, "green": 0.4, "blue": 0.4}             # #666666 — Subtitle
WHITE = {"red": 1, "green": 1, "blue": 1}
CODE_BG = {"red": 0.94, "green": 0.94, "blue": 0.94}       # #efefef
CODE_FG = {"red": 0.094, "green": 0.502, "blue": 0.220}    # #18803a
HEADER_BG = {"red": 0.26, "green": 0.26, "blue": 0.26}     # #424242
ALT_ROW_BG = {"red": 0.97, "green": 0.97, "blue": 0.97}    # #f7f7f7

# ── Heading Style Definitions ─────────────────────────────────────
# Maps namedStyleType -> (para_overrides, text_overrides)
HEADING_STYLES = {
    "TITLE": (
        {"spaceAbove": 0, "spaceBelow": 3, "lineSpacing": 115},
        {"fontFamily": "Arial", "fontSize": 24, "bold": True, "fg": DARK},
    ),
    "SUBTITLE": (
        {"spaceAbove": 0, "spaceBelow": 14, "lineSpacing": 115},
        {"fontFamily": "Arial", "fontSize": 13, "bold": False, "italic": True, "fg": GRAY},
    ),
    "HEADING_1": (
        {"spaceAbove": 20, "spaceBelow": 8, "lineSpacing": 115, "keepWithNext": True},
        {"fontFamily": "Arial", "fontSize": 20, "bold": True, "fg": DARK},
    ),
    "HEADING_2": (
        {"spaceAbove": 18, "spaceBelow": 6, "lineSpacing": 115, "keepWithNext": True},
        {"fontFamily": "Arial", "fontSize": 16, "bold": True, "fg": H2_COLOR},
    ),
    "HEADING_3": (
        {"spaceAbove": 14, "spaceBelow": 4, "lineSpacing": 115, "keepWithNext": True},
        {"fontFamily": "Arial", "fontSize": 13, "bold": True, "fg": H3_COLOR},
    ),
    "HEADING_4": (
        {"spaceAbove": 12, "spaceBelow": 4, "lineSpacing": 115, "keepWithNext": True},
        {"fontFamily": "Arial", "fontSize": 11, "bold": True, "fg": H4_COLOR},
    ),
    "HEADING_5": (
        {"spaceAbove": 10, "spaceBelow": 4, "lineSpacing": 115, "keepWithNext": True},
        {"fontFamily": "Arial", "fontSize": 11, "bold": True, "italic": True, "fg": GRAY},
    ),
    "HEADING_6": (
        {"spaceAbove": 10, "spaceBelow": 4, "lineSpacing": 115, "keepWithNext": True},
        {"fontFamily": "Arial", "fontSize": 10, "bold": True, "italic": True, "fg": GRAY},
    ),
}


# ── API Helpers ───────────────────────────────────────────────────

def pt(val):
    return {"magnitude": val, "unit": "PT"}


def color_obj(rgb):
    return {"color": {"rgbColor": rgb}}


def gws_get_doc(doc_id):
    """Fetch document via gws CLI."""
    result = subprocess.run(
        ["gws", "docs", "documents", "get",
         "--params", json.dumps({"documentId": doc_id})],
        capture_output=True, text=True,
    )
    text = result.stdout
    idx = text.find("{")
    if idx < 0:
        print(f"ERROR: gws returned no JSON: {text[:200]}", file=sys.stderr)
        sys.exit(1)
    doc = json.loads(text[idx:])
    if "error" in doc:
        code = doc["error"].get("code", "?")
        msg = doc["error"].get("message", "unknown")
        print(f"ERROR: Get document failed (HTTP {code}): {msg}", file=sys.stderr)
        if code in (401, 403):
            print("  Authentication may have expired. Run: gcloud auth login", file=sys.stderr)
        sys.exit(1)
    return doc


def gws_batch_update(doc_id, requests):
    """Send batchUpdate via gws CLI."""
    body = json.dumps({"requests": requests})
    result = subprocess.run(
        ["gws", "docs", "documents", "batchUpdate",
         "--params", json.dumps({"documentId": doc_id}),
         "--json", body],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        print(f"ERROR: batchUpdate failed: {result.stderr[:300]}", file=sys.stderr)
        if result.stdout:
            print(f"  stdout: {result.stdout[:300]}", file=sys.stderr)
        sys.exit(1)
    # Check for error in response JSON
    text = result.stdout
    idx = text.find("{")
    if idx >= 0:
        resp = json.loads(text[idx:])
        if "error" in resp:
            code = resp["error"].get("code", "?")
            msg = resp["error"].get("message", "unknown")
            print(f"ERROR: batchUpdate failed (HTTP {code}): {msg}", file=sys.stderr)
            sys.exit(1)


# ── Document Analysis ─────────────────────────────────────────────

def get_para_text(para):
    """Get raw text from paragraph elements."""
    return "".join(
        e.get("textRun", {}).get("content", "") for e in para.get("elements", [])
    )


def has_inline_object(elements):
    """True if any element is an inline object (image)."""
    return any("inlineObjectElement" in e for e in elements)


def has_link_in_range(elements):
    """True if any textRun contains a link."""
    return any(
        e.get("textRun", {}).get("textStyle", {}).get("link")
        for e in elements
    )


def snapshot_integrity(doc):
    """Count links, images, tables, and end index for integrity checks."""
    links = images = tables = 0
    for el in doc["body"]["content"]:
        if "table" in el:
            tables += 1
        if "paragraph" not in el:
            continue
        for pe in el["paragraph"]["elements"]:
            if "inlineObjectElement" in pe:
                images += 1
            if pe.get("textRun", {}).get("textStyle", {}).get("link"):
                links += 1
    end_index = doc["body"]["content"][-1]["endIndex"]
    return {"links": links, "images": images, "tables": tables, "end_index": end_index}


def verify_integrity(before, after):
    """Compare snapshots. Returns True if OK."""
    ok = True
    for key in ("links", "images", "tables"):
        if before[key] != after[key]:
            print(f"  WARNING: {key} changed from {before[key]} to {after[key]}", file=sys.stderr)
            ok = False
    if ok:
        print(
            f"  VERIFIED: {after['links']} links, {after['images']} images, "
            f"{after['tables']} tables preserved",
            file=sys.stderr,
        )
    return ok


# ── Tier 1: Generic Formatters ────────────────────────────────────

def style_paragraphs(doc, mode):
    """Style all paragraphs by namedStyleType."""
    requests = []

    for el in doc["body"]["content"]:
        if "paragraph" not in el:
            continue

        para = el["paragraph"]
        named_style = para.get("paragraphStyle", {}).get("namedStyleType", "NORMAL_TEXT")
        elements = para.get("elements", [])
        start = el["startIndex"]
        end = el["endIndex"]

        if has_inline_object(elements):
            continue

        contains_link = has_link_in_range(elements)
        # Never use fields:"*" on text ranges with links — it clears the link
        text_fields = (
            "weightedFontFamily,fontSize,bold,italic,foregroundColor"
            if contains_link else "*"
        )

        if named_style in HEADING_STYLES:
            para_def, text_def = HEADING_STYLES[named_style]

            # Paragraph style
            ps = {
                "namedStyleType": named_style,
                "alignment": "START",
                "spaceAbove": pt(para_def["spaceAbove"]),
                "spaceBelow": pt(para_def["spaceBelow"]),
                "lineSpacing": para_def["lineSpacing"],
            }
            p_fields = "namedStyleType,alignment,spaceAbove,spaceBelow,lineSpacing"
            if para_def.get("keepWithNext"):
                ps["keepWithNext"] = True
                p_fields += ",keepWithNext"

            if mode == "template-aware":
                # Only set namedStyleType
                requests.append({"updateParagraphStyle": {
                    "range": {"startIndex": start, "endIndex": end},
                    "paragraphStyle": {"namedStyleType": named_style},
                    "fields": "namedStyleType",
                }})
            else:
                requests.append({"updateParagraphStyle": {
                    "range": {"startIndex": start, "endIndex": end},
                    "paragraphStyle": ps,
                    "fields": p_fields,
                }})

                # Text style
                ts = {
                    "weightedFontFamily": {
                        "fontFamily": text_def["fontFamily"],
                        "weight": 700 if text_def.get("bold") else 400,
                    },
                    "fontSize": pt(text_def["fontSize"]),
                    "bold": text_def.get("bold", False),
                    "italic": text_def.get("italic", False),
                    "foregroundColor": color_obj(text_def["fg"]),
                }
                requests.append({"updateTextStyle": {
                    "range": {"startIndex": start, "endIndex": end},
                    "textStyle": ts,
                    "fields": text_fields,
                }})

        elif named_style == "NORMAL_TEXT":
            if mode == "template-aware":
                continue  # Don't override template body styles

            requests.append({"updateParagraphStyle": {
                "range": {"startIndex": start, "endIndex": end},
                "paragraphStyle": {
                    "namedStyleType": "NORMAL_TEXT",
                    "alignment": "START",
                    "spaceAbove": pt(0),
                    "spaceBelow": pt(6),
                    "lineSpacing": 115,
                },
                "fields": "namedStyleType,alignment,spaceAbove,spaceBelow,lineSpacing",
            }})
            requests.append({"updateTextStyle": {
                "range": {"startIndex": start, "endIndex": end},
                "textStyle": {
                    "weightedFontFamily": {"fontFamily": "Arial", "weight": 400},
                    "fontSize": pt(11),
                    "bold": False,
                    "italic": False,
                    "foregroundColor": color_obj(BODY),
                },
                "fields": text_fields,
            }})

    return requests


def style_tables(doc, mode):
    """Style tables: dark header row, alternating data rows, padding."""
    requests = []

    for el in doc["body"]["content"]:
        if "table" not in el:
            continue

        table = el["table"]
        table_start = el["startIndex"]

        for ri, row in enumerate(table["tableRows"]):
            for ci, cell in enumerate(row["tableCells"]):
                cell_content = cell.get("content", [])
                if not cell_content:
                    continue
                cs = cell_content[0]["startIndex"]
                ce = cell_content[-1]["endIndex"]

                if ri == 0:
                    # Header row
                    if mode != "template-aware":
                        requests.append({"updateTextStyle": {
                            "range": {"startIndex": cs, "endIndex": ce},
                            "textStyle": {
                                "weightedFontFamily": {"fontFamily": "Arial", "weight": 700},
                                "fontSize": pt(10),
                                "bold": True,
                                "italic": False,
                                "foregroundColor": color_obj(WHITE),
                            },
                            "fields": "*",
                        }})
                    requests.append({"updateTableCellStyle": {
                        "tableRange": {
                            "tableCellLocation": {
                                "tableStartLocation": {"index": table_start},
                                "rowIndex": 0,
                                "columnIndex": ci,
                            },
                            "rowSpan": 1,
                            "columnSpan": 1,
                        },
                        "tableCellStyle": {
                            "backgroundColor": color_obj(HEADER_BG),
                            "paddingTop": pt(4),
                            "paddingBottom": pt(4),
                            "paddingLeft": pt(6),
                            "paddingRight": pt(6),
                        },
                        "fields": "backgroundColor,paddingTop,paddingBottom,paddingLeft,paddingRight",
                    }})
                else:
                    # Data row
                    if mode != "template-aware":
                        requests.append({"updateTextStyle": {
                            "range": {"startIndex": cs, "endIndex": ce},
                            "textStyle": {
                                "weightedFontFamily": {"fontFamily": "Arial", "weight": 400},
                                "fontSize": pt(10),
                                "bold": False,
                                "italic": False,
                                "foregroundColor": color_obj(BODY),
                            },
                            "fields": "*",
                        }})
                    cell_style = {
                        "paddingTop": pt(3),
                        "paddingBottom": pt(3),
                        "paddingLeft": pt(6),
                        "paddingRight": pt(6),
                    }
                    fields = "paddingTop,paddingBottom,paddingLeft,paddingRight"
                    if ri % 2 == 0:
                        cell_style["backgroundColor"] = color_obj(ALT_ROW_BG)
                        fields += ",backgroundColor"
                    requests.append({"updateTableCellStyle": {
                        "tableRange": {
                            "tableCellLocation": {
                                "tableStartLocation": {"index": table_start},
                                "rowIndex": ri,
                                "columnIndex": ci,
                            },
                            "rowSpan": 1,
                            "columnSpan": 1,
                        },
                        "tableCellStyle": cell_style,
                        "fields": fields,
                    }})

    return requests


def style_existing_bullets(doc, mode):
    """Adjust spacing on paragraphs that already have bullets."""
    if mode == "template-aware":
        return []

    requests = []
    for el in doc["body"]["content"]:
        if "paragraph" not in el:
            continue
        para = el["paragraph"]
        if "bullet" not in para:
            continue
        start = el["startIndex"]
        end = el["endIndex"]
        requests.append({"updateParagraphStyle": {
            "range": {"startIndex": start, "endIndex": end},
            "paragraphStyle": {"spaceAbove": pt(0), "spaceBelow": pt(2)},
            "fields": "spaceAbove,spaceBelow",
        }})
    return requests


# ── Tier 2: Configurable Heuristic Formatters ─────────────────────

def find_code_block_ranges(doc, config):
    """Identify code block ranges by sentinel characters and patterns."""
    body = doc["body"]["content"]
    code_patterns = config.get("code_patterns", [])
    min_lines = config.get("code_min_consecutive_lines", 3)

    def is_code_line(text_raw, text_stripped):
        if not text_stripped:
            return False
        # Google Docs code block sentinel
        if "\ue907" in text_raw:
            return True
        # Annotation markers
        if "←" in text_stripped:
            return True
        # Config-provided patterns
        for p in code_patterns:
            if text_raw.startswith(p) or text_stripped.startswith(p):
                return True
        # Generic: lines with 4+ leading spaces (indented code)
        if text_raw.startswith("    ") and not text_stripped.startswith("*"):
            return True
        return False

    ranges = []
    i = 0
    while i < len(body):
        el = body[i]
        if "paragraph" not in el:
            i += 1
            continue
        para = el["paragraph"]
        if para.get("paragraphStyle", {}).get("namedStyleType", "") != "NORMAL_TEXT":
            i += 1
            continue
        elements = para.get("elements", [])
        if has_inline_object(elements):
            i += 1
            continue

        text_raw = get_para_text(para)
        text_stripped = text_raw.strip()

        if is_code_line(text_raw, text_stripped):
            block_start = el["startIndex"]
            block_end = el["endIndex"]
            j = i + 1
            while j < len(body):
                nxt = body[j]
                if "paragraph" not in nxt:
                    break
                np = nxt["paragraph"]
                if np.get("paragraphStyle", {}).get("namedStyleType", "") != "NORMAL_TEXT":
                    break
                if has_inline_object(np.get("elements", [])):
                    break
                nt_raw = get_para_text(np)
                nt_stripped = nt_raw.strip()

                if is_code_line(nt_raw, nt_stripped):
                    block_end = nxt["endIndex"]
                    j += 1
                    continue
                # Include blank lines if next non-blank is code
                if nt_stripped == "" and j + 1 < len(body):
                    la = body[j + 1]
                    if "paragraph" in la:
                        la_raw = get_para_text(la["paragraph"])
                        la_stripped = la_raw.strip()
                        if is_code_line(la_raw, la_stripped):
                            block_end = nxt["endIndex"]
                            j += 1
                            continue
                break

            if j - i >= min_lines:
                ranges.append((block_start, block_end))
            i = j
        else:
            i += 1

    return ranges


def style_code_blocks(code_ranges, mode):
    """Apply code block styling: Roboto Mono, green text, gray shading."""
    requests = []
    for start, end in code_ranges:
        requests.append({"updateParagraphStyle": {
            "range": {"startIndex": start, "endIndex": end},
            "paragraphStyle": {
                "namedStyleType": "NORMAL_TEXT",
                "spaceAbove": pt(0),
                "spaceBelow": pt(0),
                "lineSpacing": 115,
                "shading": {"backgroundColor": color_obj(CODE_BG)},
                "indentStart": pt(18),
                "indentEnd": pt(18),
            },
            "fields": "namedStyleType,spaceAbove,spaceBelow,lineSpacing,shading,indentStart,indentEnd",
        }})
        if mode != "template-aware":
            requests.append({"updateTextStyle": {
                "range": {"startIndex": start, "endIndex": end},
                "textStyle": {
                    "weightedFontFamily": {"fontFamily": "Roboto Mono", "weight": 400},
                    "fontSize": pt(9),
                    "bold": False,
                    "italic": False,
                    "foregroundColor": color_obj(CODE_FG),
                },
                "fields": "weightedFontFamily,fontSize,bold,italic,foregroundColor",
            }})
    return requests


def find_bullet_candidates(doc, config):
    """Find NORMAL_TEXT paragraphs that should become bullets."""
    body = doc["body"]["content"]
    starters = config.get("bullet_starters", [])
    ranges = []

    for el in body:
        if "paragraph" not in el:
            continue
        para = el["paragraph"]
        if para.get("paragraphStyle", {}).get("namedStyleType", "") != "NORMAL_TEXT":
            continue
        if "bullet" in para:
            continue
        elements = para.get("elements", [])
        if has_inline_object(elements):
            continue

        text = get_para_text(para)
        text_stripped = text.strip()

        matched = False
        # Config-provided starters
        for s in starters:
            if text_stripped.startswith(s):
                matched = True
                break
        # Generic: lines starting with "- " or "* " (markdown-style bullets)
        if not matched and (text_stripped.startswith("- ") or text_stripped.startswith("* ")):
            matched = True

        if matched:
            ranges.append((el["startIndex"], el["endIndex"]))

    return ranges


def style_new_bullets(bullet_ranges):
    """Create bullet formatting for identified ranges."""
    requests = []
    for start, end in bullet_ranges:
        requests.append({"createParagraphBullets": {
            "range": {"startIndex": start, "endIndex": end},
            "bulletPreset": "BULLET_DISC_CIRCLE_SQUARE",
        }})
        requests.append({"updateParagraphStyle": {
            "range": {"startIndex": start, "endIndex": end},
            "paragraphStyle": {"spaceAbove": pt(0), "spaceBelow": pt(2)},
            "fields": "spaceAbove,spaceBelow",
        }})
    return requests


def find_bold_label_ranges(doc, config):
    """Find paragraphs with label: value patterns to bold the label."""
    body = doc["body"]["content"]
    explicit_labels = config.get("bold_labels", [])
    ranges = []

    # Generic pattern: line starts with a capitalized word(s) followed by colon+space
    label_pattern = re.compile(r"^[A-Z][^:]{1,50}:\s")

    for el in body:
        if "paragraph" not in el:
            continue
        para = el["paragraph"]
        if has_inline_object(para.get("elements", [])):
            continue

        text_raw = get_para_text(para)
        text_stripped = text_raw.strip()
        if not text_stripped:
            continue

        # Check explicit labels first
        for label in explicit_labels:
            if text_stripped.startswith(label):
                offset = len(text_raw) - len(text_raw.lstrip())
                label_end = el["startIndex"] + offset + len(label)
                if label_end <= el["endIndex"]:
                    ranges.append((el["startIndex"] + offset, label_end))
                break
        else:
            # Generic: "Label:" pattern
            m = label_pattern.match(text_stripped)
            if m:
                offset = len(text_raw) - len(text_raw.lstrip())
                # Bold up to and including the colon
                colon_pos = text_stripped.index(":")
                label_end = el["startIndex"] + offset + colon_pos + 1
                if label_end <= el["endIndex"]:
                    ranges.append((el["startIndex"] + offset, label_end))

    return ranges


def style_bold_labels(bold_ranges):
    """Apply bold to label portions."""
    requests = []
    for start, end in bold_ranges:
        requests.append({"updateTextStyle": {
            "range": {"startIndex": start, "endIndex": end},
            "textStyle": {"bold": True},
            "fields": "bold",
        }})
    return requests


# ── Orchestration ─────────────────────────────────────────────────

def load_config(path):
    """Load optional JSON config file."""
    if not path:
        return {}
    with open(path) as f:
        return json.load(f)


def main():
    parser = argparse.ArgumentParser(
        description="Apply Canonical Style Table to a Google Doc in-place."
    )
    parser.add_argument("doc_id", help="Google Doc ID")
    parser.add_argument(
        "--mode", default="fresh-doc", choices=["fresh-doc", "template-aware"],
        help="Styling mode (default: fresh-doc)",
    )
    parser.add_argument(
        "--batch-size", type=int, default=150,
        help="API batch size (default: 150)",
    )
    parser.add_argument("--config", help="JSON config file for custom detection patterns")
    parser.add_argument("--dry-run", action="store_true", help="Preview without applying")
    args = parser.parse_args()

    config = load_config(args.config)

    # Step 1: Read document and snapshot
    print("Reading document...", file=sys.stderr)
    doc = gws_get_doc(args.doc_id)
    before = snapshot_integrity(doc)
    print(f"Document: {doc['title']}", file=sys.stderr)
    print(
        f"Baseline: {before['links']} links, {before['images']} images, "
        f"{before['tables']} tables, end_index={before['end_index']}",
        file=sys.stderr,
    )

    # Step 2: Build requests (ordered for correct override behavior)
    all_requests = []

    # Tier 1
    print("Tier 1: Styling paragraphs...", file=sys.stderr)
    para_reqs = style_paragraphs(doc, args.mode)
    print(f"  {len(para_reqs)} paragraph requests", file=sys.stderr)

    print("Tier 1: Styling tables...", file=sys.stderr)
    table_reqs = style_tables(doc, args.mode)
    print(f"  {len(table_reqs)} table requests", file=sys.stderr)

    print("Tier 1: Styling existing bullets...", file=sys.stderr)
    bullet_reqs = style_existing_bullets(doc, args.mode)
    print(f"  {len(bullet_reqs)} existing bullet requests", file=sys.stderr)

    all_requests.extend(para_reqs)
    all_requests.extend(table_reqs)
    all_requests.extend(bullet_reqs)

    # Tier 2
    print("Tier 2: Detecting code blocks...", file=sys.stderr)
    code_ranges = find_code_block_ranges(doc, config)
    code_reqs = style_code_blocks(code_ranges, args.mode)
    print(f"  {len(code_ranges)} code ranges, {len(code_reqs)} requests", file=sys.stderr)

    print("Tier 2: Detecting bullet candidates...", file=sys.stderr)
    new_bullet_ranges = find_bullet_candidates(doc, config)
    new_bullet_reqs = style_new_bullets(new_bullet_ranges)
    print(f"  {len(new_bullet_ranges)} new bullets, {len(new_bullet_reqs)} requests", file=sys.stderr)

    print("Tier 2: Detecting bold labels...", file=sys.stderr)
    bold_ranges = find_bold_label_ranges(doc, config)
    bold_reqs = style_bold_labels(bold_ranges)
    print(f"  {len(bold_ranges)} bold labels, {len(bold_reqs)} requests", file=sys.stderr)

    all_requests.extend(code_reqs)
    all_requests.extend(new_bullet_reqs)
    all_requests.extend(bold_reqs)

    total = len(all_requests)
    print(f"\nTotal: {total} requests", file=sys.stderr)

    if args.dry_run:
        print(f"DRY RUN: {total} requests would be sent")
        return

    if total == 0:
        print("No formatting changes needed.")
        return

    # Step 3: Execute in batches
    total_batches = (total + args.batch_size - 1) // args.batch_size
    for i in range(0, total, args.batch_size):
        batch = all_requests[i : i + args.batch_size]
        batch_num = i // args.batch_size + 1
        print(f"  Batch {batch_num}/{total_batches} ({len(batch)} requests)...", file=sys.stderr)
        gws_batch_update(args.doc_id, batch)

    # Step 4: Verify integrity
    print("\nVerifying integrity...", file=sys.stderr)
    doc_after = gws_get_doc(args.doc_id)
    after = snapshot_integrity(doc_after)
    ok = verify_integrity(before, after)

    status = "OK" if ok else "WARNING"
    print(f"Formatted: {total} style updates applied ({status})")


if __name__ == "__main__":
    main()
