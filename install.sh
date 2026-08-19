#!/usr/bin/env bash
# agent-helm installer (macOS / Linux)
# Usage:
#   ./install.sh [target-project-dir]      install into one project (default: cwd)
#   ./install.sh --global                  install for your user, all projects
#   ./install.sh --uninstall [target-dir]  remove from a project
#   ./install.sh --global --uninstall      remove the global install
set -euo pipefail

MODE="project"
ACTION="install"
TARGET_ARG=""
for arg in "$@"; do
  case "$arg" in
    --global) MODE="global" ;;
    --uninstall) ACTION="uninstall" ;;
    *) TARGET_ARG="$arg" ;;
  esac
done

SRC="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || pwd)"
TARGET="$(cd "${TARGET_ARG:-.}" && pwd)"

# Standalone mode (curl | bash): no repo files next to the script — fetch them.
if [ ! -f "$SRC/core/AGENTS.md" ]; then
  TARBALL="${AGENT_HELM_TARBALL:-https://github.com/suleymanbyzt/agent-helm/archive/refs/heads/master.tar.gz}"
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  echo "Fetching agent-helm..."
  curl -fsSL "$TARBALL" | tar -xz -C "$TMP" --strip-components=1
  SRC="$TMP"
fi

START_MARK="<!-- agent-helm:start -->"
END_MARK="<!-- agent-helm:end -->"

# Insert/refresh a marked agent-helm block inside a user-level config file,
# leaving everything else in that file untouched. Idempotent.
install_block() {
  local file="$1" content="$2"
  mkdir -p "$(dirname "$file")"
  if [ -f "$file" ] && grep -qF "$START_MARK" "$file"; then
    awk -v start="$START_MARK" -v end="$END_MARK" -v src="$content" '
      $0 == start { print; while ((getline line < src) > 0) print line; skip = 1; next }
      $0 == end   { skip = 0 }
      !skip' "$file" > "$file.agent-helm.tmp"
    mv "$file.agent-helm.tmp" "$file"
    echo "  ~ $file (agent-helm block refreshed)"
  else
    { [ -s "$file" ] && echo ""; echo "$START_MARK"; cat "$content"; echo "$END_MARK"; } >> "$file"
    echo "  + $file (agent-helm block added)"
  fi
}

# Remove the marked block; delete the file if nothing else remains.
remove_block() {
  local file="$1"
  [ -f "$file" ] || return 0
  if grep -qF "$START_MARK" "$file"; then
    awk -v start="$START_MARK" -v end="$END_MARK" '
      $0 == start { skip = 1; next }
      $0 == end   { skip = 0; next }
      !skip' "$file" > "$file.agent-helm.tmp"
    mv "$file.agent-helm.tmp" "$file"
    if ! grep -q '[^[:space:]]' "$file"; then rm -f "$file"; fi
    echo "  - $file (agent-helm block removed)"
  fi
}

copy_skills() {
  local dest="$1"
  mkdir -p "$dest"
  for skill in "$SRC"/skills/*/; do
    local name
    name="$(basename "$skill")"
    mkdir -p "$dest/$name"
    cp "$skill/SKILL.md" "$dest/$name/SKILL.md"
  done
  echo "  + $dest/ ($(ls -1 "$SRC/skills" | wc -l | tr -d ' ') skills)"
}

remove_skills() {
  local dest="$1"
  [ -d "$dest" ] || return 0
  for skill in "$SRC"/skills/*/; do
    rm -rf "$dest/$(basename "$skill")"
  done
  rmdir "$dest" 2>/dev/null || true
  echo "  - $dest/ (agent-helm skills removed)"
}

# Remove a file only if it is byte-identical to ours (never a user-edited copy).
remove_if_ours() {
  local ours="$1" theirs="$2"
  [ -f "$theirs" ] || return 0
  if cmp -s "$ours" "$theirs"; then
    rm -f "$theirs"
    echo "  - $theirs"
  else
    echo "  ! $theirs was modified — left in place, review it yourself."
  fi
}

# ---------------------------------------------------------------- uninstall --
if [ "$ACTION" = "uninstall" ]; then
  if [ "$MODE" = "global" ]; then
    echo "Removing global agent-helm install"
    remove_block "$HOME/.claude/CLAUDE.md"
    remove_skills "$HOME/.claude/skills"
    remove_block "$HOME/.codex/AGENTS.md"
    remove_skills "$HOME/.agents/skills"
  else
    echo "Removing agent-helm from: $TARGET"
    remove_if_ours "$SRC/core/AGENTS.md" "$TARGET/AGENTS.md"
    remove_if_ours "$SRC/core/AGENTS.md" "$TARGET/AGENTS.helm.md"
    remove_if_ours "$SRC/core/CLAUDE.md" "$TARGET/CLAUDE.md"
    remove_skills "$TARGET/.claude/skills"
    remove_skills "$TARGET/.agents/skills"
    rmdir "$TARGET/.claude" "$TARGET/.agents" 2>/dev/null || true
    remove_if_ours "$SRC/templates/journal.md" "$TARGET/templates/journal.md"
    remove_if_ours "$SRC/templates/integration-brief.md" "$TARGET/templates/integration-brief.md"
    rmdir "$TARGET/templates" 2>/dev/null || true
    # Journals and briefs are YOUR project history — never deleted.
    for dir in "$TARGET/docs/agent-journal" "$TARGET/docs/briefs"; do
      if [ -d "$dir" ]; then
        rm -f "$dir/.gitkeep"
        if rmdir "$dir" 2>/dev/null; then
          echo "  - $dir/ (was empty)"
        else
          echo "  = $dir/ kept — your journal entries stay yours."
        fi
      fi
    done
    rmdir "$TARGET/docs" 2>/dev/null || true
  fi
  echo ""
  echo "Done."
  exit 0
fi

# ------------------------------------------------------------ global install --
if [ "$MODE" = "global" ]; then
  echo "Installing agent-helm globally (for your user, all projects)"

  # Claude Code: ~/.claude/CLAUDE.md = constitution + advisor loop, ~/.claude/skills/
  BLOCK="$(mktemp)"
  cat "$SRC/core/AGENTS.md" > "$BLOCK"
  grep -v '^@AGENTS.md' "$SRC/core/CLAUDE.md" >> "$BLOCK"
  install_block "$HOME/.claude/CLAUDE.md" "$BLOCK"
  rm -f "$BLOCK"
  copy_skills "$HOME/.claude/skills"

  # Codex: ~/.codex/AGENTS.md = constitution, ~/.agents/skills/
  install_block "$HOME/.codex/AGENTS.md" "$SRC/core/AGENTS.md"
  copy_skills "$HOME/.agents/skills"

  echo ""
  echo "Done. Applies to all YOUR projects (new sessions). Teammates are not"
  echo "affected — for team-wide rules, run the per-project install and commit."
  exit 0
fi

# ----------------------------------------------------------- project install --
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

# 2. CLAUDE.md — imports AGENTS.md (official pattern) + Claude-specific setup
if [ -f "$TARGET/CLAUDE.md" ]; then
  if cmp -s "$SRC/core/CLAUDE.md" "$TARGET/CLAUDE.md"; then
    echo "  = CLAUDE.md already up to date"
  elif grep -q "@AGENTS.md" "$TARGET/CLAUDE.md"; then
    echo "  = CLAUDE.md exists and imports AGENTS.md — keeping yours."
    echo "    (See core/CLAUDE.md for the recommended advisor-loop setup.)"
  else
    echo "  ! CLAUDE.md already exists. Add this line to it yourself: @AGENTS.md"
  fi
else
  cp "$SRC/core/CLAUDE.md" "$TARGET/CLAUDE.md"
  echo "  + CLAUDE.md (imports AGENTS.md + advisor loop)"
fi

# 3. Skills — same files, both agents' native locations
#    Claude Code: .claude/skills/   Codex: .agents/skills/
copy_skills "$TARGET/.claude/skills"
copy_skills "$TARGET/.agents/skills"

# 4. Templates + journal/brief directories
mkdir -p "$TARGET/docs/agent-journal" "$TARGET/docs/briefs" "$TARGET/templates"
cp "$SRC/templates/journal.md" "$TARGET/templates/journal.md"
cp "$SRC/templates/integration-brief.md" "$TARGET/templates/integration-brief.md"
touch "$TARGET/docs/agent-journal/.gitkeep" "$TARGET/docs/briefs/.gitkeep"
echo "  + templates/, docs/agent-journal/, docs/briefs/"

echo ""
echo "Done. Commit the new files so the whole team's agents use the same rules."
