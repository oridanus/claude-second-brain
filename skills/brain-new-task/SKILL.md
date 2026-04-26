---
name: brain-new-task
description: Create a new task in the second brain
user_invocable: true
---

# Brain New Task

Create a new task in `~/projects/brain/tasks/`.

## Instructions

The user's input after `/brain-new-task` is the task title (and optionally body/tags/priority).

### Steps

1. **Parse the input:** The text is the task title. If the user includes `priority: high/medium/low` or `tags: [...]`, extract those. Default priority is `medium`.

2. **Generate the filename:** `{epoch}-{slug}.md` where epoch is `date +%s` and slug is derived from the first ~5 words of the title, lowercased, hyphened, max 40 chars.

3. **Write the file** to `~/projects/brain/tasks/{epoch}-{slug}.md`:
   ```markdown
   ---
   type: task
   title: {Title}
   status: open
   priority: {priority}
   created: {ISO-8601 timestamp}
   session_id: {CLAUDE_SESSION_ID first 12 chars, or "unknown"}
   tags: [{tags}]
   where_stopped: ""
   ---
   {Body if provided, otherwise repeat the title}
   ```

4. **Confirm** by printing the path and title.

5. **Issue tracker linkage check** (optional — Asana, Jira, Linear, GitHub Issues, etc.):
   - If an issue-tracker MCP/CLI is configured, search for an equivalent task by title keywords.
   - If a match exists → ask the user to confirm linking, then add `tracker_url:` (or a tracker-specific field like `asana_gid:`, `jira_key:`, `linear_id:`) to the frontmatter.
   - If no match → ask: **"Internal-only, or should this be logged in your issue tracker too?"**
     - If "log it" → create the tracker task (or guide the user) and store the id/url back in the brain task frontmatter.
     - If "internal" → no action.
   - Skip this step if the user's input already declared intent (e.g. "internal task: …" or includes a tracker URL).
