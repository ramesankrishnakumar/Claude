#!/bin/bash
# Apply Canonical Style Table formatting to an existing Google Doc in-place
# Usage: format_doc.sh DOC_ID [--mode fresh-doc|template-aware] [--batch-size N] [--config PATH] [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

check_dependencies || exit 1

if ! command -v python3 &>/dev/null; then
    echo "ERROR: python3 not found." >&2
    exit 1
fi

DOC_ID=""
MODE="fresh-doc"
BATCH_SIZE=150
CONFIG_PATH=""
DRY_RUN=false

print_usage() {
    cat <<'EOF'
Apply Canonical Style Table formatting to an existing Google Doc in-place

Usage: format_doc.sh DOC_ID [OPTIONS]

Arguments:
  DOC_ID                Google Doc ID or URL

Options:
      --mode MODE       Styling mode: fresh-doc (default), template-aware
      --batch-size N    API batch size (default: 150)
      --config PATH     JSON config file for custom detection patterns
      --dry-run         Show what would be styled without applying changes
  -h, --help            Show this help

Modes:
  fresh-doc         Apply full Canonical Style Table — fonts, sizes, colors,
                    spacing on every paragraph. Use for new or unstyled docs.
  template-aware    Only set namedStyleType — preserve template fonts and
                    colors. Still applies table structure and code shading.

Config file (JSON, all fields optional):
  {
    "code_patterns": ["@page ", "left-sidebar", ...],
    "code_min_consecutive_lines": 3,
    "bullet_starters": ["DOM extraction as primary", ...],
    "bold_labels": ["Bottleneck:", "Status:", ...]
  }

Safety:
  Never inserts or deletes content. Preserves all links, images, and tables.
  Verifies integrity before and after formatting.

Examples:
  format_doc.sh DOC_ID                                    # Full canonical styling
  format_doc.sh DOC_ID --mode template-aware               # Preserve template
  format_doc.sh "https://docs.google.com/..." --dry-run    # Preview changes
  format_doc.sh DOC_ID --config patterns.json              # Custom patterns
EOF
}

if [[ $# -eq 0 ]]; then
    print_usage
    exit 1
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --mode) MODE="$2"; shift 2 ;;
        --batch-size) BATCH_SIZE="$2"; shift 2 ;;
        --config) CONFIG_PATH="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        -h|--help) print_usage; exit 0 ;;
        -*)
            echo "Unknown option: $1" >&2
            print_usage >&2
            exit 1
            ;;
        *)
            if [[ -z "$DOC_ID" ]]; then
                DOC_ID=$(extract_doc_id "$1") || exit 1
            else
                echo "Unexpected argument: $1" >&2
                print_usage >&2
                exit 1
            fi
            shift
            ;;
    esac
done

if [[ -z "$DOC_ID" ]]; then
    echo "ERROR: Document ID is required" >&2
    print_usage >&2
    exit 1
fi

# Validate mode
if [[ "$MODE" != "fresh-doc" && "$MODE" != "template-aware" ]]; then
    echo "ERROR: Invalid mode '$MODE'. Must be 'fresh-doc' or 'template-aware'" >&2
    exit 1
fi

# Validate config file if provided
if [[ -n "$CONFIG_PATH" && ! -f "$CONFIG_PATH" ]]; then
    echo "ERROR: Config file not found: $CONFIG_PATH" >&2
    exit 1
fi

# Build Python args
PYTHON_ARGS=("$SCRIPT_DIR/format_doc.py" "$DOC_ID" "--mode" "$MODE" "--batch-size" "$BATCH_SIZE")

[[ -n "$CONFIG_PATH" ]] && PYTHON_ARGS+=("--config" "$CONFIG_PATH")
[[ "$DRY_RUN" == "true" ]] && PYTHON_ARGS+=("--dry-run")

# Run the Python formatting engine
python3 "${PYTHON_ARGS[@]}"
RC=$?

if [[ $RC -ne 0 ]]; then
    exit $RC
fi

echo "URL: https://docs.google.com/document/d/$DOC_ID/edit"
