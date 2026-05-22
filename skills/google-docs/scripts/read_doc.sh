#!/bin/bash
# Read the plain text content of a Google Doc
# Usage: read_doc.sh DOC_ID

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

check_dependencies || exit 1

DOC_ID=""

print_usage() {
    cat <<'EOF'
Read the plain text content of a Google Doc

Usage: read_doc.sh DOC_ID

Arguments:
  DOC_ID                Google Doc ID or URL

Options:
  -h, --help            Show this help

Examples:
  read_doc.sh DOC_ID                       # Read document content
  read_doc.sh https://docs.google.com/document/d/DOC_ID/edit
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
        -h|--help) print_usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; print_usage >&2; exit 1 ;;
    esac
done

RESPONSE=$(gws_json docs documents get \
    --params "$(jq -n --arg id "$DOC_ID" '{"documentId":$id}')")

if ! handle_gws_error "$RESPONSE" "Read document"; then
    exit 1
fi

echo "$RESPONSE" | jq -r '
    .body.content[]? |
    select(.paragraph) |
    .paragraph.elements[]? |
    select(.textRun) |
    .textRun.content // ""
' | tr -d '\r'
