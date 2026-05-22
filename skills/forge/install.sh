#!/usr/bin/env bash
# Install forge and composed skills (Linux + macOS).
#
# Copies each skill into ~/.agents/skills/<name>/ and symlinks ~/.claude/skills/<name>.
#
# Usage: ./skills/forge/install.sh [--dry-run] [--with-google-docs]

set -euo pipefail

DRY_RUN=0
WITH_GOOGLE_DOCS=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --with-google-docs) WITH_GOOGLE_DOCS=1 ;;
    -h|--help)
      echo "Usage: $0 [--dry-run] [--with-google-docs]"
      exit 0
      ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

SKILLS=(
  forge
  manage-issues
  commit-and-create-pr
  design-doc
  plan-to-html
)
if [ "$WITH_GOOGLE_DOCS" = "1" ]; then
  SKILLS+=(google-docs)
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENTS_DIR="$HOME/.agents/skills"
CLAUDE_DIR="$HOME/.claude/skills"

run() {
  if [ "$DRY_RUN" = "1" ]; then
    echo "DRY  $*"
  else
    eval "$@"
  fi
}

install_skill() {
  local name="$1"
  local src="$SKILLS_SRC_ROOT/$name"
  local agents_target="$AGENTS_DIR/$name"
  local claude_link="$CLAUDE_DIR/$name"

  if [ ! -d "$src" ]; then
    echo "error: source not found: $src" >&2
    exit 1
  fi

  run "mkdir -p \"$AGENTS_DIR\""
  run "rsync -a --delete \"$src/\" \"$agents_target/\""
  echo "COPY  $src -> $agents_target"

  run "mkdir -p \"$CLAUDE_DIR\""
  if [ -L "$claude_link" ]; then
    local current
    current="$(readlink "$claude_link")"
    if [ "$current" = "$agents_target" ]; then
      echo "OK    $claude_link -> $agents_target"
      return 0
    fi
    run "rm \"$claude_link\""
  elif [ -e "$claude_link" ]; then
    run "rm -rf \"$claude_link\""
  fi
  run "ln -s \"$agents_target\" \"$claude_link\""
  echo "LINK  $claude_link -> $agents_target"
}

for name in "${SKILLS[@]}"; do
  install_skill "$name"
done

echo ""
echo "Done. Forge config: ~/.claude/forge-config.json (run forge init)."
echo "Optional: $0 --with-google-docs"
