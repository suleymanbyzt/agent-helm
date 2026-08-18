#!/usr/bin/env bash
# agent-helm installer (macOS / Linux)
# Usage: ./install.sh [target-project-dir]   (default: current directory)
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$(cd "${1:-.}" && pwd)"

echo "Installing agent-helm into: $TARGET"

# 1. AGENTS.md — the constitution (read natively by Codex, Cursor, Copilot, ...)
if [ -f "$TARGET/AGENTS.md" ]; then
  if cmp -s "$SRC/core/AGENTS.md" "$TARGET/AGENTS.md"; then
    echo "  = AGENTS.md already up to date"
  else
    cp "$SRC/core/AGENTS.md" "$TARGET/AGENTS.helm.md"
    echo "  ! AGENTS.md already exists — wrote AGENTS.helm.md instead."
    echo "    Merge it into your AGENTS.md manually."
  fi
else
  cp "$SRC/core/AGENTS.md" "$TARGET/AGENTS.md"
  echo "  + AGENTS.md"
fi

# 2. CLAUDE.md — Claude Code reads CLAUDE.md; import AGENTS.md (official pattern)
if [ -f "$TARGET/CLAUDE.md" ]; then
  if ! grep -q "@AGENTS.md" "$TARGET/CLAUDE.md"; then
    echo "  ! CLAUDE.md already exists. Add this line to it yourself: @AGENTS.md"
  else
    echo "  = CLAUDE.md already imports AGENTS.md"
  fi
else
  printf '@AGENTS.md\n' > "$TARGET/CLAUDE.md"
  echo "  + CLAUDE.md (imports AGENTS.md)"
fi

# 3. Skills — same files, both agents' native locations
#    Claude Code: .claude/skills/   Codex: .agents/skills/
for dest in ".claude/skills" ".agents/skills"; do
  mkdir -p "$TARGET/$dest"
  for skill in "$SRC"/skills/*/; do
    name="$(basename "$skill")"
    mkdir -p "$TARGET/$dest/$name"
    cp "$skill/SKILL.md" "$TARGET/$dest/$name/SKILL.md"
  done
  echo "  + $dest/ ($(ls -1 "$SRC/skills" | wc -l | tr -d ' ') skills)"
done

# 4. Templates + journal/brief directories
mkdir -p "$TARGET/docs/agent-journal" "$TARGET/docs/briefs" "$TARGET/templates"
cp "$SRC/templates/journal.md" "$TARGET/templates/journal.md"
cp "$SRC/templates/integration-brief.md" "$TARGET/templates/integration-brief.md"
touch "$TARGET/docs/agent-journal/.gitkeep" "$TARGET/docs/briefs/.gitkeep"
echo "  + templates/, docs/agent-journal/, docs/briefs/"

echo ""
echo "Done. Commit the new files so the whole team's agents use the same rules."
