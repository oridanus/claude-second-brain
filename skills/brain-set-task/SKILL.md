---
name: brain-set-task
description: Set the current Claude session to work on a brain task
user_invocable: true
---

# Brain Set Task

Assign the current Claude session to an existing task from `~/projects/brain/tasks/`.

## Instructions

The user's input after `/brain-set-task` is a fuzzy task name, optionally followed by an issue-tracker URL (Asana, Jira, Linear, GitHub Issues, etc.). Examples:
- `/brain-set-task workflow` → matches "Workflow running in prod"
- `/brain-set-task auth https://example.atlassian.net/browse/AUTH-123` → matches "Auth refactor" and saves the tracker link
- `/brain-set-task social` → matches "Social checks"

### Steps

1. **Parse input:** Split the user's input into a fuzzy task name and an optional tracker URL (any `https://` token).

2. **List all open tasks:** Read `title:` from frontmatter of all files in `~/projects/brain/tasks/` where `status: open`.

3. **Fuzzy match:** Find tasks whose title contains the user's input (case-insensitive).
   - If exactly **one match**: use it.
   - If **multiple matches**: ask the user to pick using `AskUserQuestion`, showing the matching titles as options.
   - If **no match**: tell the user no task matched and show the list of open tasks.

4. **Find the terminal session ID:**
   ```bash
   # Detect terminal: cmux (Ghostty) or iTerm2
   if command -v cmux &>/dev/null; then
     # cmux: get the caller workspace ref
     CALLER_WORKSPACE=$(cmux identify 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['caller']['workspace_ref'])" 2>/dev/null)
   fi
   ```

5. **Link session to task:** Update the matched task file:
   - Set `iterm_session:` in frontmatter to the caller workspace ref (e.g. `workspace:1`) or iTerm session ID
   - Also update `session_id:` to the SHORT_ID for backward compat
   - If a tracker URL was provided, set `tracker_url:` in frontmatter

6. **Set tab title** using the detected terminal:
   ```bash
   # cmux (Ghostty)
   if [[ -n "$CALLER_WORKSPACE" ]]; then
     cmux rename-workspace --workspace "$CALLER_WORKSPACE" "{task title}"
   else
     # Fallback: ANSI escape sequence (works in most terminals)
     printf '\033]0;{task title}\007'
   fi
   ```

7. **Confirm** by printing: "Session linked to: {task title}"

This link means:
- The terminal tab shows the task name (via cmux or ANSI escape).
- The status-hook will use this task's `title` in macOS notifications when the session stops.
- Only THIS tab gets the title — other Claude sessions are unaffected.
