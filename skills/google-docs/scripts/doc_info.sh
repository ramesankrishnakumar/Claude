#!/bin/bash
# Get metadata about a Google Doc
# Usage: doc_info.sh DOC_ID [--format json]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

check_dependencies || exit 1

DOC_ID=""
OUTPUT_FORMAT="text"

print_usage() {
    cat <<'EOF'
Get metadata about a Google Doc

Usage: doc_info.sh DOC_ID [OPTIONS]

Arguments:
  DOC_ID                Google Doc ID or URL

Options:
  --format FORMAT       Output format: text, json (default: text)
  -h, --help            Show this help

Examples:
  doc_info.sh DOC_ID                 # Get document info
  doc_info.sh DOC_ID --format json   # Get document info as JSON
EOF
}

if [[ $# -eq 0 ]]; then
    print_usage
    exit 1
fi

DOC_ID=$(extract_doc_id "$1") || exit 1
shift

while [[ $# -gt 0 ]]; do
    case $1 in
        --format) OUTPUT_FORMAT="$2"; shift 2 ;;
        -h|--help) print_usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; print_usage >&2; exit 1 ;;
    esac
done

RESPONSE=$(gws_json docs documents get \
    --params "$(jq -n --arg id "$DOC_ID" '{"documentId":$id}')")

if ! handle_gws_error "$RESPONSE" "Get document info"; then
    exit 1
fi

case "$OUTPUT_FORMAT" in
    json)
        echo "$RESPONSE" | jq '.'
        ;;
    text)
        echo "Document Information"
        echo "==================="
        echo ""
        echo "Title:        $(echo "$RESPONSE" | jq -r '.title')"
        echo "Document ID:  $(echo "$RESPONSE" | jq -r '.documentId')"
        echo ""
        echo "URL:          https://docs.google.com/document/d/$DOC_ID/edit"

        REVISION_ID=$(echo "$RESPONSE" | jq -r '.revisionId // "N/A"')
        if [[ "$REVISION_ID" != "N/A" && -n "$REVISION_ID" ]]; then
            echo "Revision ID:  $REVISION_ID"
        fi

        MARGINS=$(echo "$RESPONSE" | jq -r '.documentStyle // empty')
        if [[ -n "$MARGINS" && "$MARGINS" != "null" ]]; then
            echo ""
            echo "Document Style:"
            PAGE_WIDTH=$(echo "$RESPONSE" | jq -r '.documentStyle.pageSize.width.magnitude // "N/A"')
            PAGE_HEIGHT=$(echo "$RESPONSE" | jq -r '.documentStyle.pageSize.height.magnitude // "N/A"')
            if [[ "$PAGE_WIDTH" != "N/A" ]]; then
                echo "  Page Size:  ${PAGE_WIDTH}pt x ${PAGE_HEIGHT}pt"
            fi
        fi

        CONTENT_LENGTH=$(echo "$RESPONSE" | jq '[.body.content[].endIndex] | max // 0')
        echo ""
        echo "Content length: ~$CONTENT_LENGTH characters"
        ;;
    *)
        echo "Unknown format: $OUTPUT_FORMAT" >&2
        exit 1
        ;;
esac
