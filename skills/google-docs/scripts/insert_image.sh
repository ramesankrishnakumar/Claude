#!/bin/bash
# Insert an image into a Google Doc from a publicly accessible URL
# Usage: insert_image.sh DOC_ID IMAGE_URL [--index N] [--width W] [--height H]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

check_dependencies || exit 1

DOC_ID=""
IMAGE_URL=""
INSERT_INDEX=""
WIDTH=""
HEIGHT=""

print_usage() {
    cat <<'EOF'
Insert an image into a Google Doc

Usage: insert_image.sh DOC_ID IMAGE_URL [OPTIONS]

Arguments:
  DOC_ID                Google Doc ID or URL
  IMAGE_URL              Publicly accessible image URL

Options:
      --index N          Insert at specific index (default: end of document)
      --width W          Image width in points (72pt = 1 inch)
      --height H         Image height in points (optional, preserves aspect ratio if only width)
  -h, --help             Show this help

Examples:
  insert_image.sh DOC_ID "https://..."                    # Insert at end
  insert_image.sh DOC_ID "https://..." --index 1         # Insert at start
  insert_image.sh DOC_ID "https://..." --width 400       # Specify width

The image must be publicly accessible. Corporate policies may block public sharing.
See image-workflow.md for workarounds.
EOF
}

if [[ $# -lt 2 ]]; then
    print_usage
    exit 1
fi

DOC_ID=$(extract_doc_id "$1") || exit 1
shift
IMAGE_URL="$1"
shift

if [[ ! "$IMAGE_URL" =~ ^https?:// ]]; then
    echo "ERROR: IMAGE_URL must be a valid http or https URL" >&2
    exit 1
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --index) INSERT_INDEX="$2"; shift 2 ;;
        --width) WIDTH="$2"; shift 2 ;;
        --height) HEIGHT="$2"; shift 2 ;;
        -h|--help) print_usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; print_usage >&2; exit 1 ;;
    esac
done

# Determine insert index: explicit or end of document
if [[ -z "$INSERT_INDEX" ]]; then
    DOC_RESPONSE=$(gws_json docs documents get \
        --params "$(jq -n --arg id "$DOC_ID" '{"documentId":$id,"fields":"body.content"}')")

    if ! handle_gws_error "$DOC_RESPONSE" "Get document"; then
        exit 1
    fi

    END_INDEX=$(echo "$DOC_RESPONSE" | jq '[.body.content[].endIndex] | max')
    INSERT_INDEX=$((END_INDEX - 1))
fi

# Build objectSize if width/height specified
OBJECT_SIZE_JSON=""
if [[ -n "$WIDTH" && -n "$HEIGHT" ]]; then
    OBJECT_SIZE_JSON=$(jq -n -c --argjson w "$WIDTH" --argjson h "$HEIGHT" '{
        width: { magnitude: $w, unit: "PT" },
        height: { magnitude: $h, unit: "PT" }
    }')
elif [[ -n "$WIDTH" ]]; then
    OBJECT_SIZE_JSON=$(jq -n -c --argjson w "$WIDTH" '{width: { magnitude: $w, unit: "PT" }}')
elif [[ -n "$HEIGHT" ]]; then
    OBJECT_SIZE_JSON=$(jq -n -c --argjson h "$HEIGHT" '{height: { magnitude: $h, unit: "PT" }}')
fi

# Build batchUpdate request
if [[ -n "$OBJECT_SIZE_JSON" ]]; then
    REQUEST=$(jq -n -c --arg uri "$IMAGE_URL" --argjson index "$INSERT_INDEX" --argjson size "$OBJECT_SIZE_JSON" '{
        requests: [{
            insertInlineImage: {
                uri: $uri,
                location: { index: $index },
                objectSize: $size
            }
        }]
    }')
else
    REQUEST=$(jq -n -c --arg uri "$IMAGE_URL" --argjson index "$INSERT_INDEX" '{
        requests: [{
            insertInlineImage: {
                uri: $uri,
                location: { index: $index }
            }
        }]
    }')
fi

RESPONSE=$(gws_json docs documents batchUpdate \
    --params "$(jq -n --arg id "$DOC_ID" '{"documentId":$id}')" \
    --json "$REQUEST")

if ! handle_gws_error "$RESPONSE" "Insert image"; then
    if echo "$RESPONSE" | grep -q "Internal error"; then
        echo "" >&2
        echo "HINT: Image insertion failed. Common causes:" >&2
        echo "  - Image URL is not publicly accessible" >&2
        echo "  - Corporate Workspace policies block public sharing" >&2
        echo "" >&2
        echo "Workarounds:" >&2
        echo "  - Include Drive view links in doc instead of embedding" >&2
        echo "  - Manual insertion: Insert > Image > Drive in Google Docs UI" >&2
        echo "  - Host images externally (GitHub, S3) with public access" >&2
    fi
    exit 1
fi

echo "Image inserted successfully into document: $DOC_ID"
echo "URL: https://docs.google.com/document/d/$DOC_ID/edit"
