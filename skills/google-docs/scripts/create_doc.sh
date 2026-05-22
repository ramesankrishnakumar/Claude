#!/bin/bash
# Create a new Google Doc with optional Markdown content
# Usage: create_doc.sh "Title" ["Content"] [--markdown]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

check_dependencies || exit 1

TITLE=""
CONTENT=""
USE_MARKDOWN=false

print_usage() {
    cat <<'EOF'
Create a new Google Doc

Usage: create_doc.sh TITLE [CONTENT] [OPTIONS]

Arguments:
  TITLE                 Document title
  CONTENT               Initial content (optional)

Options:
      --markdown        Convert content from Markdown to formatted text
  -h, --help            Show this help

Examples:
  create_doc.sh "My Document"                              # Create empty doc
  create_doc.sh "My Document" "Hello, world!"              # Create with plain text
  create_doc.sh "Report" "# Summary\n\n- Item 1" --markdown  # Create with Markdown
EOF
}

if [[ $# -eq 0 ]]; then
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
            if [[ -z "$TITLE" ]]; then
                TITLE="$1"
            elif [[ -z "$CONTENT" ]]; then
                CONTENT="$1"
            else
                echo "Unexpected argument: $1" >&2
                print_usage >&2
                exit 1
            fi
            shift
            ;;
    esac
done

if [[ -z "$TITLE" ]]; then
    echo "ERROR: Title is required" >&2
    print_usage >&2
    exit 1
fi

if [[ "$USE_MARKDOWN" == "true" && -n "$CONTENT" ]]; then
    # Write markdown content to a temp file, then use gws drive upload
    CONTENT=$(printf '%b' "$CONTENT")
    TMPFILE=$(mktemp "${PWD}/.gws_md_XXXXXX.md")
    trap 'rm -f "$TMPFILE"' EXIT
    echo "$CONTENT" > "$TMPFILE"

    RESPONSE=$(gws_json drive files create \
        --params '{"fields":"id,name,webViewLink"}' \
        --json "$(jq -n --arg name "$TITLE" '{"name":$name,"mimeType":"application/vnd.google-apps.document"}')" \
        --upload "$(basename "$TMPFILE")" \
        --upload-content-type text/markdown)

    if ! handle_gws_error "$RESPONSE" "Create document"; then
        exit 1
    fi

    FILE_ID=$(echo "$RESPONSE" | jq -r '.id')
    echo "Document ID: $FILE_ID"
    echo "URL: https://docs.google.com/document/d/$FILE_ID/edit"
else
    # Use Docs API for plain text
    RESPONSE=$(gws_json docs documents create \
        --json "$(jq -n --arg title "$TITLE" '{title: $title}')")

    if ! handle_gws_error "$RESPONSE" "Create document"; then
        exit 1
    fi

    DOC_ID=$(echo "$RESPONSE" | jq -r '.documentId')

    # Insert content if provided
    if [[ -n "$CONTENT" ]]; then
        CONTENT=$(printf '%b' "$CONTENT")
        [[ "${CONTENT: -1}" != $'\n' ]] && CONTENT+=$'\n'

        UPDATE_RESPONSE=$(gws_json docs documents batchUpdate \
            --params "$(jq -n --arg id "$DOC_ID" '{"documentId":$id}')" \
            --json "$(jq -n --arg text "$CONTENT" '{"requests":[{"insertText":{"location":{"index":1},"text":$text}}]}')")

        if ! handle_gws_error "$UPDATE_RESPONSE" "Insert content"; then
            exit 1
        fi
    fi

    echo "Document ID: $DOC_ID"
    echo "URL: https://docs.google.com/document/d/$DOC_ID/edit"
fi
