#!/usr/bin/env bash
# Resolve the brain task name for the current cmux workspace.
# Outputs the task title to stdout, or nothing if no match.
set -uo pipefail

BRAIN_TASKS="$HOME/projects/brain/tasks"
WORKSPACE_REF=""
WORKSPACE_NAME=""

# Get cmux workspace
if command -v cmux &>/dev/null; then
  CMUX_JSON=$(cmux identify 2>/dev/null || true)
  if [[ -n "$CMUX_JSON" ]]; then
    WORKSPACE_REF=$(python3 -c "import sys,json; print(json.load(sys.stdin)['caller']['workspace_ref'])" <<< "$CMUX_JSON" 2>/dev/null || true)
  fi
  if [[ -n "$WORKSPACE_REF" ]]; then
    WORKSPACE_NAME=$(cmux list-workspaces 2>/dev/null | grep -E "(^|[^0-9])${WORKSPACE_REF}( |$)" | head -1 | sed 's/^[* ]*'"$WORKSPACE_REF"' *//; s/ *\[selected\] *$//' || true)
  fi
fi

[[ -z "$WORKSPACE_REF" ]] && exit 0

# Check open tasks for direct workspace_ref match
if [[ -d "$BRAIN_TASKS" ]]; then
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    iterm=$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f&&/^iterm_session:/{gsub(/^iterm_session: */,"");print}' "$file")
    if [[ "$iterm" == "$WORKSPACE_REF" ]]; then
      awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f&&/^title:/{gsub(/^title: *"?/,"");gsub(/"$/,"");print}' "$file"
      exit 0
    fi
  done < <(grep -l "status: open" "$BRAIN_TASKS"/*.md 2>/dev/null)

  # Exact name match
  if [[ -n "$WORKSPACE_NAME" ]]; then
    WS_L=$(echo "$WORKSPACE_NAME" | tr '[:upper:]' '[:lower:]')
    while IFS= read -r file; do
      [[ -z "$file" ]] && continue
      title=$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f&&/^title:/{gsub(/^title: *"?/,"");gsub(/"$/,"");print}' "$file")
      T_L=$(echo "$title" | tr '[:upper:]' '[:lower:]')
      if [[ "$WS_L" == "$T_L" ]]; then
        echo "$title"
        exit 0
      fi
    done < <(grep -l "status: open" "$BRAIN_TASKS"/*.md 2>/dev/null)
  fi
fi

# No direct match — output workspace name as fallback
[[ -n "$WORKSPACE_NAME" ]] && echo "$WORKSPACE_NAME"
