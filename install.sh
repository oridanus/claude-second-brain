#!/usr/bin/env bash
# Installs Claude Second Brain.
# - Copies bin/ scripts into ~/projects/brain/bin
# - Symlinks skills/* into ~/.claude/skills
# - Creates the runtime directory structure
# - Prints the settings.json hook snippet
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRAIN_DIR="$HOME/projects/brain"
SKILLS_DIR="$HOME/.claude/skills"

echo "→ Creating $BRAIN_DIR"
mkdir -p "$BRAIN_DIR"/{bin,tasks,findings,decisions,progress,goals,statuses}

echo "→ Copying bin/ scripts"
cp -R "$REPO_DIR"/bin/. "$BRAIN_DIR"/bin/
chmod +x "$BRAIN_DIR"/bin/*.sh "$BRAIN_DIR"/bin/*.py 2>/dev/null || true

if [[ ! -f "$BRAIN_DIR/names.json" ]]; then
  echo "{}" > "$BRAIN_DIR/names.json"
fi

echo "→ Symlinking skills into $SKILLS_DIR"
mkdir -p "$SKILLS_DIR"
for skill_dir in "$REPO_DIR"/skills/*/; do
  name=$(basename "$skill_dir")
  target="$SKILLS_DIR/$name"
  if [[ -e "$target" && ! -L "$target" ]]; then
    echo "  ! $name already exists at $target (not a symlink) — skipped"
    continue
  fi
  ln -sfn "$skill_dir" "$target"
  echo "  ✓ $name"
done

cat <<EOF

Done. To enable hooks, add to ~/.claude/settings.json:

  "hooks": {
    "SessionStart": [
      { "hooks": [{ "type": "command", "command": "$BRAIN_DIR/bin/session-start-hook.sh" }] }
    ],
    "PostToolUse": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "$BRAIN_DIR/bin/status-hook.sh post_tool_use" }] }
    ],
    "Stop": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "$BRAIN_DIR/bin/status-hook.sh stop" }] }
    ]
  }

Then run: /brain
EOF
