#!/usr/bin/env bash
# Claude Code status line inspired by Starship / Catppuccin Mocha theme

input=$(cat)

# --- Claude context ---
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')

# --- Directory (just current folder name) ---
short_dir="${cwd##*/}"

# --- Git branch & status (skip locks to be safe) ---
git_branch=""
git_status_str=""
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  # Counts
  modified=$(git -C "$cwd" status --porcelain 2>/dev/null | grep -c '^.M\|^M' || true)
  untracked=$(git -C "$cwd" status --porcelain 2>/dev/null | grep -c '^??' || true)
  staged=$(git -C "$cwd" status --porcelain 2>/dev/null | grep -c '^[MADRC]' || true)

  status_parts=""
  [ "$staged" -gt 0 ]    && status_parts="${status_parts}+${staged} "
  [ "$modified" -gt 0 ]  && status_parts="${status_parts}!${modified} "
  [ "$untracked" -gt 0 ] && status_parts="${status_parts}?${untracked} "

  git_status_str=$(echo "$status_parts" | sed 's/[[:space:]]*$//')
fi

# --- ANSI colors (Catppuccin Mocha approximations via 256-color) ---
# peach  ~208, yellow ~220, green ~114, lavender ~147, dim ~245, reset
PEACH='\033[38;5;208m'
YELLOW='\033[38;5;220m'
GREEN='\033[38;5;114m'
LAVENDER='\033[38;5;147m'
DIM='\033[38;5;245m'
BOLD='\033[1m'
RESET='\033[0m'

# --- Assemble ---
# macOS symbol
line="${BOLD}${DIM}󰀵 ${RESET}"

# Directory
line="${line}${BOLD}${PEACH}${short_dir}${RESET} "

# Git branch
if [ -n "$git_branch" ]; then
  line="${line}${BOLD}${YELLOW}[on  ${git_branch}]${RESET} "
  if [ -n "$git_status_str" ]; then
    line="${line}${BOLD}${YELLOW}[${git_status_str}]${RESET} "
  fi
fi

# Model + context bar
line="${line}${DIM}|${RESET} ${BOLD}${LAVENDER}${model}${RESET}"
if [ -n "$used_pct" ]; then
  used_int=${used_pct%.*}
  line="${line} ${DIM}ctx:${used_int}%${RESET}"
fi
if [ -n "$cost" ]; then
  cost=$(printf '%.2f' "$cost")
  line="${line} ${GREEN}\$${cost}${RESET}"
fi

printf "%b\n" "$line"
