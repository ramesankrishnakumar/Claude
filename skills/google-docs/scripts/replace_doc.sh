#!/bin/bash
# Replace all content in a Google Doc
# Usage: replace_doc.sh DOC_ID "New content" [--markdown]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

check_dependencies || exit 1

DOC_ID=""
NEW_CONTENT=""
USE_MARKDOWN=false

print_usage() {
    cat <<'EOF'
Replace all content in a Google Doc

Usage: replace_doc.sh DOC_ID CONTENT [OPTIONS]

Arguments:
  DOC_ID                Google Docs document ID or URL
  CONTENT               New content for the document

Options:
      --markdown        Convert content from Markdown (creates new doc)
  -h, --help            Show this help

Note: With --markdown, a new document is created because the Drive API
doesn't support in-place Markdown conversion.

Examples:
  replace_doc.sh DOC_ID "New content"
  replace_doc.sh DOC_ID "# New Heading\n\nNew text" --markdown
EOF
}

if [[ $# -lt 2 ]]; then
    print_usage
    exit 1
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --markdown) USE_MARKDOWN=true; shift ;;
        -h|--help) print_usage; exit 0 ;;
        -*)
            echo "Unknown option: $1" >&2
            print_usage >&2
            exit 1
            ;;
        *)
            if [[ -z "$DOC_ID" ]]; then
                DOC_ID=$(extract_doc_id "$1") || exit 1
            elif [[ -z "$NEW_CONTENT" ]]; then
                NEW_CONTENT="$1"
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

if [[ -z "$NEW_CONTENT" ]]; then
    echo "ERROR: Content is required" >&2
    print_usage >&2
    exit 1
fi

if [[ "$USE_MARKDOWN" == "true" ]]; then
    # Get original document title
    DOC_RESPONSE=$(gws_json docs documents get \
        --params "$(jq -n --arg id "$DOC_ID" '{"documentId":$id}')")

    if ! handle_gws_error "$DOC_RESPONSE" "Get document"; then
        exit 1
    fi

    TITLE=$(echo "$DOC_RESPONSE" | jq -r '.title')
    NEW_CONTENT=$(printf '%b' "$NEW_CONTENT")

    # Write to temp file in cwd (gws --upload constraint)
    TMPFILE=$(mktemp "${PWD}/.gws_md_XXXXXX.md")
    trap 'rm -f "$TMPFILE"' EXIT
    echo "$NEW_CONTENT" > "$TMPFILE"

    RESPONSE=$(gws_json drive files create \
        --params '{"fields":"id,name,webViewLink"}' \
        --json "$(jq -n --arg name "$TITLE" '{"name":$name,"mimeType":"application/vnd.google-apps.document"}')" \
        --upload "$(basename "$TMPFILE")" \
        --upload-content-type text/markdown)

    if ! handle_gws_error "$RESPONSE" "Create document"; then
        exit 1
    fi

    NEW_DOC_ID=$(echo "$RESPONSE" | jq -r '.id')
    echo "New Document ID: $NEW_DOC_ID"
    echo "URL: https://docs.google.com/document/d/$NEW_DOC_ID/edit"
    echo "Note: Markdown conversion creates a new document"
else
    # Get current document to find content range
    DOC_RESPONSE=$(gws_json docs documents get \
        --params "$(jq -n --arg id "$DOC_ID" '{"documentId":$id}')")

    if ! handle_gws_error "$DOC_RESPONSE" "Get document"; then
        exit 1
    fi

    END_INDEX=$(echo "$DOC_RESPONSE" | jq '[.body.content[]? | .endIndex // 0] | max')

    REQUESTS="[]"

    # Delete existing content if there is any
    if [[ $END_INDEX -gt 2 ]]; then
        DELETE_END=$((END_INDEX - 1))
        REQUESTS=$(echo "$REQUESTS" | jq --argjson end "$DELETE_END" '. + [{
            deleteContentRange: {
                range: {startIndex: 1, endIndex: $end}
            }
        }]')
    fi

    # Add new content
    NEW_CONTENT=$(printf '%b' "$NEW_CONTENT")
    [[ "${NEW_CONTENT: -1}" != $'\n' ]] && NEW_CONTENT+=$'\n'

    REQUESTS=$(echo "$REQUESTS" | jq --arg text "$NEW_CONTENT" '. + [{
        insertText: {
            location: {index: 1},
            text: $text
        }
    }]')

    UPDATE_BODY=$(echo "$REQUESTS" | jq '{requests: .}')

    RESPONSE=$(gws_json docs documents batchUpdate \
        --params "$(jq -n --arg id "$DOC_ID" '{"documentId":$id}')" \
        --json "$UPDATE_BODY")

    if ! handle_gws_error "$RESPONSE" "Replace content"; then
        exit 1
    fi

    echo "Content replaced in document: $DOC_ID"
fi
