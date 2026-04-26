#!/usr/bin/env bash
set -uo pipefail

# Safety: kill self after 5 seconds to never block session start
( sleep 5; kill $$ 2>/dev/null ) & disown

# --- Parse input ---
INPUT=$(cat)
SOURCE=$(python3 -c "import sys,json; print(json.load(sys.stdin).get('source',''))" <<< "$INPUT" 2>/dev/null)

case "$SOURCE" in
  startup|resume) ;;
  *) exit 0 ;;
esac

SESSION_ID=$(python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" <<< "$INPUT" 2>/dev/null)
[[ -z "$SESSION_ID" ]] && exit 0
SHORT_ID="${SESSION_ID:0:12}"

BRAIN_DIR="$HOME/projects/brain"
BRAIN_TASKS="$BRAIN_DIR/tasks"
BRAIN_GOALS="$BRAIN_DIR/goals"
NAMES_FILE="$BRAIN_DIR/names.json"

# --- Active week goals ---
WEEK_GOALS=""
if [[ -d "$BRAIN_GOALS" ]]; then
  TODAY=$(date +%Y-%m-%d)
  for f in "$BRAIN_GOALS"/*.md; do
    [[ -f "$f" ]] || continue
    WS=$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f&&/^week_start:/{gsub(/^week_start: */,"");print}' "$f")
    WE=$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f&&/^week_end:/{gsub(/^week_end: */,"");print}' "$f")
    ST=$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f&&/^status:/{gsub(/^status: */,"");print}' "$f")
    [[ "$ST" != "active" ]] && continue
    if [[ -n "$WS" ]] && [[ "$TODAY" < "$WS" ]]; then continue; fi
    if [[ -n "$WE" ]] && [[ "$TODAY" > "$WE" ]]; then continue; fi
    WEEK_GOALS=$(awk '/^---$/{c++;next} c>=2' "$f")
    break
  done
fi

# --- cmux workspace ---
WORKSPACE_REF=""
WORKSPACE_NAME=""
if command -v cmux &>/dev/null; then
  CMUX_JSON=$(cmux identify 2>/dev/null || true)
  if [[ -n "$CMUX_JSON" ]]; then
    WORKSPACE_REF=$(python3 -c "import sys,json; print(json.load(sys.stdin)['caller']['workspace_ref'])" <<< "$CMUX_JSON" 2>/dev/null || true)
  fi
  if [[ -n "$WORKSPACE_REF" ]]; then
    WORKSPACE_NAME=$(cmux list-workspaces 2>/dev/null | grep -E "(^|[^0-9])${WORKSPACE_REF}( |$)" | head -1 | sed 's/^[* ]*'"$WORKSPACE_REF"' *//; s/ *\[selected\] *$//' || true)
  fi
fi

# --- CC session name ---
SESSION_NAME=""
if [[ -f "$NAMES_FILE" ]]; then
  SESSION_NAME=$(python3 << PYEOF
import json
d = json.load(open("$NAMES_FILE"))
print(d.get("$SHORT_ID", ""))
PYEOF
  ) 2>/dev/null || true
fi

# --- Scan open tasks ---
declare -a T_FILES=() T_TITLES=() T_SIDS=() T_ITERMS=() T_WS=() T_PRIOS=()

if [[ -d "$BRAIN_TASKS" ]]; then
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    T_FILES+=("$file")
    T_TITLES+=("$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f&&/^title:/{gsub(/^title: *"?/,"");gsub(/"$/,"");print}' "$file")")
    T_SIDS+=("$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f&&/^session_id:/{gsub(/^session_id: */,"");print}' "$file")")
    T_ITERMS+=("$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f&&/^iterm_session:/{gsub(/^iterm_session: */,"");print}' "$file")")
    T_WS+=("$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f&&/^where_stopped:/{gsub(/^where_stopped: *"?/,"");gsub(/"$/,"");print}' "$file")")
    T_PRIOS+=("$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f&&/^priority:/{gsub(/^priority: */,"");print}' "$file")")
  done < <(grep -l "status: open" "$BRAIN_TASKS"/*.md 2>/dev/null)
fi

TASK_COUNT=${#T_FILES[@]}

# --- Link task helper ---
link_task() {
  local file="$1" title="$2"

  # Update task frontmatter
  grep -q "^session_id:" "$file" && sed -i '' "s/^session_id: .*/session_id: $SHORT_ID/" "$file"
  if [[ -n "$WORKSPACE_REF" ]]; then
    grep -q "^iterm_session:" "$file" && sed -i '' "s|^iterm_session: .*|iterm_session: $WORKSPACE_REF|" "$file"
  fi

  # Update names.json
  if [[ -f "$NAMES_FILE" ]]; then
    python3 << PYEOF
import json
f = "$NAMES_FILE"
d = json.load(open(f))
d["$SHORT_ID"] = "$title"
json.dump(d, open(f, "w"), indent=2)
PYEOF
  fi 2>/dev/null || true

  # Rename cmux workspace
  if [[ -n "$WORKSPACE_REF" && "$WORKSPACE_NAME" != "$title" ]]; then
    cmux rename-workspace --workspace "$WORKSPACE_REF" "$title" 2>/dev/null || true
  fi
}

# --- Build task list ---
build_task_list() {
  for ((i=0; i<TASK_COUNT; i++)); do
    local ws=""
    [[ -n "${T_WS[$i]}" ]] && ws=" | where_stopped: ${T_WS[$i]}"
    echo "- ${T_TITLES[$i]} (${T_PRIOS[$i]:-medium})${ws}"
  done
}

# ========================
# MATCH
# ========================
MATCHED_IDX=-1

# 1. workspace_ref matches iterm_session
if [[ -n "$WORKSPACE_REF" ]]; then
  for ((i=0; i<TASK_COUNT; i++)); do
    [[ "${T_ITERMS[$i]}" == "$WORKSPACE_REF" ]] && { MATCHED_IDX=$i; break; }
  done
fi

# 2. session_id match
if [[ $MATCHED_IDX -eq -1 ]]; then
  for ((i=0; i<TASK_COUNT; i++)); do
    [[ -n "${T_SIDS[$i]}" && "${T_SIDS[$i]}" == "$SHORT_ID"* ]] && { MATCHED_IDX=$i; break; }
  done
fi

# 3. Exact name match (case-insensitive)
if [[ $MATCHED_IDX -eq -1 && -n "$WORKSPACE_NAME" ]]; then
  WS_L=$(echo "$WORKSPACE_NAME" | tr '[:upper:]' '[:lower:]')
  for ((i=0; i<TASK_COUNT; i++)); do
    T_L=$(echo "${T_TITLES[$i]}" | tr '[:upper:]' '[:lower:]')
    [[ "$WS_L" == "$T_L" ]] && { MATCHED_IDX=$i; break; }
  done
fi

# ========================
# OUTPUT
# ========================
if [[ $MATCHED_IDX -ge 0 ]]; then
  TITLE="${T_TITLES[$MATCHED_IDX]}"
  FILE="${T_FILES[$MATCHED_IDX]}"
  PRIO="${T_PRIOS[$MATCHED_IDX]:-medium}"
  WS="${T_WS[$MATCHED_IDX]}"

  link_task "$FILE" "$TITLE"

  CONTEXT="[Brain Task Linked]
Task: \"$TITLE\"
File: $FILE
Priority: $PRIO"
  [[ -n "$WS" ]] && CONTEXT+=$'\n'"Where you stopped: $WS"
  [[ -n "$WEEK_GOALS" ]] && CONTEXT+=$'\n\n'"[Active Week Goals]"$'\n'"$WEEK_GOALS"
  CONTEXT+=$'\n\n'"This session is now linked to the above brain task. When the user sends their first message, briefly acknowledge the task and where they left off, then address their message. If their message is just a greeting, ask what they want to focus on today."

else
  TASK_LIST=$(build_task_list)
  BEST_NAME="${WORKSPACE_NAME:-$SESSION_NAME}"

  CONTEXT="[Brain Session Hook - No Direct Match]
cmux_workspace_name: ${WORKSPACE_NAME}
cc_session_name: ${SESSION_NAME}
short_id: ${SHORT_ID}
cmux_workspace_ref: ${WORKSPACE_REF}

Open brain tasks:
${TASK_LIST}
"
  [[ -n "$WEEK_GOALS" ]] && CONTEXT+=$'\n'"[Active Week Goals]"$'\n'"${WEEK_GOALS}"$'\n'
  CONTEXT+="
Instructions:
1. Fuzzy-match the workspace name or session name against the task list.
2. Single clear match: run /brain-set-task with the task name.
3. Multiple matches: ask the user to pick.
4. No match with a name: ask user to create new task or pick from list.
5. No name at all: present task list and ask."
fi

python3 << PYEOF
import json, sys
ctx = """$CONTEXT"""
print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": ctx}}))
PYEOF
