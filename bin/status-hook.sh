#!/usr/bin/env bash
set -uo pipefail

# Get event type
EVENT_TYPE="${1:-post_tool_use}"

# Use CLAUDE_PROJECT_DIR if available, otherwise fall back to PWD
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

# Get or derive session ID
if [[ -n "${CLAUDE_SESSION_ID:-}" ]]; then
  SESSION_ID="$CLAUDE_SESSION_ID"
else
  SESSION_ID=$(echo -n "$PROJECT_ROOT" | shasum -a 256 | cut -d' ' -f1)
fi

SHORT_ID="${SESSION_ID:0:12}"

# Status
if [[ "$EVENT_TYPE" == "stop" ]]; then
  STATUS="done"
else
  STATUS="active"
fi

# Project info
PROJECT_NAME=$(basename "$PROJECT_ROOT")
PROJECT_PATH="$PROJECT_ROOT"
LOCATION="local"
PID="${PPID:-$$}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

BRAIN_DIR="$HOME/projects/brain"

# Write status file
mkdir -p "$BRAIN_DIR/statuses"
cat > "$BRAIN_DIR/statuses/${SHORT_ID}.md" << ENDFILE
---
status: $STATUS
project_name: $PROJECT_NAME
project_path: $PROJECT_PATH
location: $LOCATION
pid: $PID
session_id: $SESSION_ID
last_updated: $TIMESTAMP
---
ENDFILE

if [[ "$EVENT_TYPE" == "stop" ]]; then
  TODAY=$(date +%Y-%m-%d)
  PROGRESS_DIR="$BRAIN_DIR/progress/$TODAY"
  PROGRESS_FILE="$PROGRESS_DIR/${SHORT_ID}.md"
  NOW_TIME=$(date +%H:%M)

  mkdir -p "$PROGRESS_DIR"

  if [[ ! -f "$PROGRESS_FILE" ]]; then
    cat > "$PROGRESS_FILE" << BRAINEOF
---
type: progress
date: $TODAY
session_id: $SHORT_ID
---
BRAINEOF
  fi

  echo "## $NOW_TIME - Session stopped" >> "$PROGRESS_FILE"

  # Clean up checkpoint file
  rm -f "$BRAIN_DIR/statuses/.checkpoint-${SHORT_ID}"

  # Include where_stopped in progress entry
  TASK_FILE=$(grep -rl "session_id: $SHORT_ID" "$BRAIN_DIR/tasks/" 2>/dev/null | head -1)
  if [[ -n "$TASK_FILE" ]]; then
    WS=$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f&&/^where_stopped:/{gsub(/^where_stopped: *"?/,"");gsub(/"$/,"");print}' "$TASK_FILE")
    [[ -n "$WS" ]] && echo "Where stopped: $WS" >> "$PROGRESS_FILE"
  fi

else
  # post_tool_use: check if checkpoint reminder is due
  TASK_FILE=$(grep -rl "session_id: $SHORT_ID" "$BRAIN_DIR/tasks/" 2>/dev/null | head -1)
  if [[ -n "$TASK_FILE" ]]; then
    CHECKPOINT_FILE="$BRAIN_DIR/statuses/.checkpoint-${SHORT_ID}"
    NOW=$(date +%s)
    LAST=0
    [[ -f "$CHECKPOINT_FILE" ]] && LAST=$(cat "$CHECKPOINT_FILE")
    ELAPSED=$(( NOW - LAST ))

    if [[ $ELAPSED -ge 600 ]]; then  # 10 minutes
      echo "$NOW" > "$CHECKPOINT_FILE"
      TASK_TITLE=$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f&&/^title:/{gsub(/^title: *"?/,"");gsub(/"$/,"");print}' "$TASK_FILE")
      CURRENT_WS=$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f&&/^where_stopped:/{gsub(/^where_stopped: *"?/,"");gsub(/"$/,"");print}' "$TASK_FILE")

      TASK_TITLE="$TASK_TITLE" TASK_FILE="$TASK_FILE" CURRENT_WS="$CURRENT_WS" python3 << 'PYEOF'
import json, os
t = os.environ["TASK_TITLE"]
f = os.environ["TASK_FILE"]
w = os.environ["CURRENT_WS"]
ctx = f'[Brain Checkpoint Reminder]\nTask: "{t}"\nFile: {f}\nCurrent where_stopped: "{w}"\n\nUpdate where_stopped with a one-liner of what you\'ve accomplished since the last checkpoint. Use sed or python to update the frontmatter field. Do this silently — no need to tell the user.'
print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": ctx}}))
PYEOF
      exit 0
    fi
  fi
fi
