---
name: brain-save
description: Save to the second brain - tasks, findings, decisions, progress
user_invocable: true
---

# Brain Save Skill

Save entries to the knowledge store at `~/projects/brain/`.

## Instructions

The user's input after `/brain-save` should start with a type prefix: `finding:`, `decision:`, or `progress:`.

> **Note:** To create tasks, use `/brain-new-task` instead. `/brain-save` handles findings, decisions, and progress only.

### Steps

1. **Parse the type** from the prefix before the first colon. If no recognized prefix, default to `finding`. If the user tries `task:`, tell them to use `/brain-new-task` instead.

2. **Derive the project name:**
   - If `CLAUDE_PROJECT_DIR` is set, use `basename "$CLAUDE_PROJECT_DIR"`
   - Otherwise, use `basename "$PWD"`
   - If the result looks like a home directory or is ambiguous, use `_global`
   - The user can override by saying "project: X" in their input

3. **Generate the filename:**
   - For `task`, `finding`, `decision`: `{epoch}-{slug}.md` where epoch is `date +%s` and slug is derived from the first ~5 words of the title, lowercased, hyphened, max 40 chars
   - For `progress`: append to `~/projects/brain/progress/{YYYY-MM-DD}/{session-short-id}.md`

4. **Determine the target directory:**
   - `finding` → `~/projects/brain/findings/{project}/`
   - `decision` → `~/projects/brain/decisions/{project}/`
   - `progress` → `~/projects/brain/progress/{YYYY-MM-DD}/`
   - Create the directory if it doesn't exist

5. **Write the file:**

   For `finding`, `decision` — create a new file (no title field, just a heading):
   ```markdown
   ---
   type: {type}
   created: {ISO-8601 timestamp}
   session_id: {CLAUDE_SESSION_ID first 12 chars, or "unknown"}
   tags: [{any tags the user mentioned}]
   ---
   # {Title derived from user input}
   {Body from user input}
   ```

   For `progress` — append to existing session file (create with frontmatter if new):
   ```markdown
   ## HH:MM - {description from user input}
   {Optional details}
   ```

   If creating a new progress file, prepend frontmatter:
   ```markdown
   ---
   type: progress
   date: {YYYY-MM-DD}
   session_id: {short session id}
   ---
   ```

6. **Confirm** by printing the path of the written file and a one-line summary.
