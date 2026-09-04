#!/usr/bin/env bash
# Symlink the override skills into a target repo's .claude/skills/.
#
# Project-level skills take precedence over plugin skills of the same name,
# so this guarantees the override wins even with mattpocock-skills installed.
#
# Usage: ./scripts/link-skills.sh [target-repo]   (default: current directory)
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$(cd "${1:-$PWD}" && pwd)"

if [ "$SRC" = "$TARGET" ]; then
  echo "error: target is this repo itself" >&2
  exit 1
fi

mkdir -p "$TARGET/.claude/skills"

for skill in "$SRC"/skills/*/; do
  name="$(basename "$skill")"
  dest="$TARGET/.claude/skills/$name"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "skip  $name (a real directory already exists there)"
    continue
  fi
  ln -sfn "${skill%/}" "$dest"
  echo "link  $name -> $dest"
done

echo
echo "Done. Restart Claude Code in $TARGET to pick the skills up."
