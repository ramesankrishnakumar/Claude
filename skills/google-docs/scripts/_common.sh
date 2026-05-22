#!/bin/bash
# Shared utilities for google-docs scripts
# All scripts use `gws` CLI for authenticated Google API calls.

# Extract document ID from URL or return as-is
# Supports: full URL, edit URL, or bare document ID
extract_doc_id() {
    local input="$1"
    if [[ "$input" =~ /document/d/([a-zA-Z0-9_-]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$input" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "$input"
    else
        echo "ERROR: Cannot extract document ID from: $input" >&2
        return 1
    fi
}

# Check that gws CLI is available
check_gws() {
    if ! command -v gws &>/dev/null; then
        echo "ERROR: gws CLI not found." >&2
        echo "Install: https://github.com/googleworkspace/cli" >&2
        return 1
    fi
}

# Check that jq is available
check_jq() {
    if ! command -v jq &>/dev/null; then
        echo "ERROR: jq not found. Install with: brew install jq" >&2
        return 1
    fi
}

check_dependencies() {
    check_gws || return 1
    check_jq || return 1
}

# Run gws and parse JSON output, handling the "Using keyring backend" prefix
# Usage: gws_json <service> <resource> [<sub-resource>] <method> [flags...]
# Returns clean JSON on stdout, errors on stderr
gws_json() {
    local output
    output=$(gws "$@" 2>/dev/null)
    local rc=$?

    if [[ $rc -ne 0 ]]; then
        echo "ERROR: gws command failed" >&2
        echo "$output" >&2
        return 1
    fi

    # gws may prefix non-JSON lines; extract from first {
    if [[ "$output" == *"{"* ]]; then
        echo "$output" | python3 -c "
import sys
text = sys.stdin.read()
idx = text.find('{')
if idx >= 0:
    print(text[idx:])
else:
    print(text)
" 2>/dev/null || echo "$output"
    else
        echo "$output"
    fi
}

# Check for API error in gws JSON response
# Usage: handle_gws_error "$RESPONSE" "Operation description"
handle_gws_error() {
    local response="$1"
    local operation="$2"
    if echo "$response" | jq -e '.error' &>/dev/null; then
        local code message
        code=$(echo "$response" | jq -r '.error.code // "unknown"')
        message=$(echo "$response" | jq -r '.error.message // "unknown error"')
        echo "ERROR: $operation failed (HTTP $code): $message" >&2

        if [[ "$code" == "401" || "$code" == "403" ]]; then
            echo "" >&2
            echo "Authentication may have expired. Run:" >&2
            echo "  gcloud auth login" >&2
        fi
        return 1
    fi
    return 0
}
