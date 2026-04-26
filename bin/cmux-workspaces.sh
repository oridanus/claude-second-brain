#!/usr/bin/env bash
# Creates a cmux workspace for each open brain task.
# Usage: ./cmux-workspaces.sh

BRAIN_TASKS="$HOME/projects/brain/tasks"

# Parse open tasks from brain
open_tasks=()
while IFS= read -r file; do
  title=$(awk '/^title:/{gsub(/^title: *"?/,""); gsub(/"$/,""); print; exit}' "$file")
  [ -n "$title" ] && open_tasks+=("$title")
done < <(grep -l "status: open" "$BRAIN_TASKS"/*.md 2>/dev/null)

if [ ${#open_tasks[@]} -eq 0 ]; then
  echo "No open brain tasks found."
  exit 0
fi

# Get existing workspace names
existing=$(cmux list-workspaces 2>/dev/null)

for title in "${open_tasks[@]}"; do
  if echo "$existing" | grep -qF "$title"; then
    echo "Already exists: $title"
    continue
  fi
  cmux new-workspace 2>/dev/null
  # Get the latest workspace ref
  ws_ref=$(cmux list-workspaces 2>/dev/null | tail -1 | awk '{print $1}')
  if [ -n "$ws_ref" ]; then
    cmux rename-workspace --workspace "$ws_ref" "$title" 2>/dev/null
    echo "Created: $title"
  fi
done

echo "Done. ${#open_tasks[@]} open tasks, workspaces ready."
