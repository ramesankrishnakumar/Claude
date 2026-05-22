#!/usr/bin/env bash
# Setup script for Claude Code configuration
# Usage: ./setup.sh
#
# Symlinks config files from this repo into ~/.claude/
# Safe to re-run — backs up existing files before overwriting.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

mkdir -p "$CLAUDE_DIR"

link_file() {
  local src="$SCRIPT_DIR/$1"
  local dest="$CLAUDE_DIR/$1"

  if [ ! -f "$src" ]; then
    echo "SKIP  $1 (not found in repo)"
    return
  fi

  if [ -L "$dest" ]; then
    # Already a symlink — update it
    rm "$dest"
  elif [ -f "$dest" ]; then
    # Real file exists — back it up
    echo "BACKUP $dest -> ${dest}.bak"
    mv "$dest" "${dest}.bak"
  fi

  ln -s "$src" "$dest"
  echo "LINK  $dest -> $src"
}

link_file "CLAUDE.md"
link_file "settings.json"
link_file "statusline-command.sh"

echo ""
echo "Done. Claude Code config is now symlinked from: $SCRIPT_DIR"
echo "To undo, replace symlinks in ~/.claude/ with your own files."
