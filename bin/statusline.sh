#!/usr/bin/env bash
# Claude Code status line: show current brain task + set tab title
set -uo pipefail

# Consume stdin (Claude Code sends JSON session data)
cat > /dev/null

BRAIN_DIR="$HOME/projects/brain"
# Walk up the process tree to find a TTY
SESSION_TTY=""
PID=$$
while [[ -n "$PID" && "$PID" != "1" ]]; do
  SESSION_TTY=$(ps -o tty= -p "$PID" 2>/dev/null | tr -d ' \n' || true)
  if [[ -n "$SESSION_TTY" && "$SESSION_TTY" != "??" ]]; then
    break
  fi
  PID=$(ps -o ppid= -p "$PID" 2>/dev/null | tr -d ' \n' || true)
done

if [[ -z "${SESSION_TTY:-}" ]]; then
  exit 0
fi

ITERM_ID_FILE="$BRAIN_DIR/statuses/${SESSION_TTY}.iterm"
ITERM_SESSION_ID=$(cat "$ITERM_ID_FILE" 2>/dev/null || true)

if [[ -z "${ITERM_SESSION_ID:-}" ]]; then
  exit 0
fi

TASK_FILE=$(grep -rl "iterm_session: $ITERM_SESSION_ID" "$BRAIN_DIR/tasks/" 2>/dev/null | head -1)

if [[ -n "$TASK_FILE" ]] && grep -q 'status: open' "$TASK_FILE" 2>/dev/null; then
  TITLE=$(sed -n 's/^title: *//p' "$TASK_FILE" 2>/dev/null | head -1)
  if [[ -n "$TITLE" ]]; then
    # Output for status line (tab title is handled by status-hook)
    echo "$TITLE"
  fi
fi
