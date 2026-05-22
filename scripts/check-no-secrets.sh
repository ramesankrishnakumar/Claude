#!/usr/bin/env bash
# Fail if proprietary / personal patterns appear in tracked content.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PATTERNS=(
  '@intuit\.com'
  'github\.intuit\.com'
  'intuit-prod\.atlassian\.net'
  'intuit-1519982467571521426'
  'QBLE'
  'QB Live'
  'KK Ramesan'
  'customfield_'
  'SAE-PENDING'
  'mcp__claude_ai_Atlassian__'
  'manage-jira'
  'live-expert-agent'
)

EXCLUDE='\.git/'

fail=0
for pat in "${PATTERNS[@]}"; do
  if rg -i --glob '!.git' --glob '!scripts/check-no-secrets.sh' "$pat" . 2>/dev/null | grep -q .; then
    echo "FAIL pattern: $pat" >&2
    rg -i --glob '!.git' "$pat" . 2>/dev/null | head -20 >&2
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "OK: no blocked patterns found"
