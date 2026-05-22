#!/usr/bin/env bash
# Install Claude Code config + forge skills from this repo.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$ROOT/config/setup.sh"
"$ROOT/skills/forge/install.sh" "$@"
echo "Repo: $ROOT | Remote: git@github.com:ramesankrishnakumar/Claude.git"
