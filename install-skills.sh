#!/usr/bin/env bash
#
# install-skills.sh — install the skills in this repo into Claude Code.
#
# Claude Code auto-discovers skills from folders that contain a SKILL.md file.
# This script finds every such folder in the repo and copies it into your
# skills directory.
#
# Usage:
#   ./install-skills.sh                 # install into ~/.claude/skills (personal, all projects)
#   ./install-skills.sh --project       # install into ./.claude/skills (current project only)
#   ./install-skills.sh --target DIR    # install into a custom directory
#   ./install-skills.sh --list          # just list the skills, install nothing
#   ./install-skills.sh --dry-run       # show what would be installed
#
# After installing, restart Claude Code so it picks up the new skills.

set -euo pipefail

# Resolve the directory this script lives in (= repo root).
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET="$HOME/.claude/skills"
DRY_RUN=0
LIST_ONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)   TARGET="$(pwd)/.claude/skills"; shift ;;
    --target)    TARGET="$2"; shift 2 ;;
    --dry-run)   DRY_RUN=1; shift ;;
    --list)      LIST_ONLY=1; shift ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Collect every directory that directly contains a SKILL.md, excluding .git and
# the repo root itself (the root SKILL.md is gstack's framework entrypoint, not a
# drop-in skill — copying the whole repo as one "skill" would be wrong).
mapfile -t SKILL_DIRS < <(
  find "$REPO_DIR" -path "$REPO_DIR/.git" -prune -o -name SKILL.md -print \
    | while read -r f; do dirname "$f"; done \
    | grep -vx "$REPO_DIR" \
    | sort
)

if [[ ${#SKILL_DIRS[@]} -eq 0 ]]; then
  echo "No skills found in $REPO_DIR" >&2
  exit 1
fi

echo "Found ${#SKILL_DIRS[@]} skills in $REPO_DIR"
[[ $LIST_ONLY -eq 1 ]] || echo "Target: $TARGET"
echo

installed=0
skipped=0

for src in "${SKILL_DIRS[@]}"; do
  name="$(basename "$src")"
  dest="$TARGET/$name"

  if [[ $LIST_ONLY -eq 1 ]]; then
    echo "  $name"
    continue
  fi

  # If a different skill with the same name already exists at the target,
  # namespace this one with its parent folder to avoid clobbering.
  if [[ -e "$dest" ]]; then
    parent="$(basename "$(dirname "$src")")"
    dest="$TARGET/${parent}-${name}"
    echo "  ! name '$name' already exists at target — installing as '${parent}-${name}'"
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "  would install: $name -> $dest"
  else
    mkdir -p "$TARGET"
    cp -r "$src" "$dest"
    echo "  installed: $name"
  fi
  installed=$((installed+1))
done

echo
if [[ $LIST_ONLY -eq 1 ]]; then
  echo "(list only — nothing installed)"
elif [[ $DRY_RUN -eq 1 ]]; then
  echo "Dry run: $installed skills would be installed."
else
  echo "Done: $installed skills installed into $TARGET"
  echo "Restart Claude Code to pick them up."
fi
