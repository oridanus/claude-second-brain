---
name: brain
description: Query the second brain - dashboard, search, tasks, findings, progress, decisions, next
user_invocable: true
---

# Brain Query Skill

Query the knowledge store at `~/projects/brain/`.

## Instructions

Parse the user's argument after `/brain` to determine the subcommand. If no argument, show the dashboard.

### Subcommands

**No args (dashboard):**
1. Show current week goals: find the most recent file in `~/projects/brain/goals/` (sorted by filename = week_start date) where today's date is `>= week_start` and `<= week_end` from frontmatter. If found, display the goals at the top.
2. Count open tasks: `grep -rl 'status: open' ~/projects/brain/tasks/` (show count)
3. List the 5 most recent findings: `ls -t ~/projects/brain/findings/**/*.md 2>/dev/null | head -5` and read their `# title` lines
4. Show today's progress: read all files in `~/projects/brain/progress/$(date +%Y-%m-%d)/` if the directory exists
5. Format as a concise dashboard. If everything is empty, say "Brain is empty. Use `/brain-save` to add entries."

**`goals` / `week`:**
1. Find the active week goals file in `~/projects/brain/goals/` (status: active, today within week_start..week_end)
2. Display the full content
3. If none active, list all goals files and offer to create a new one

**`tasks`:**
→ Redirect: run `/brain-show-tasks` instead (it has the full table with priorities and where-we-stopped).

**`findings [project]`:**
1. List files in `~/projects/brain/findings/` (or `findings/{project}/` if specified)
2. Sort by modification time (newest first), show last 10
3. Display title + first line of body for each

**`progress [today|YYYY-MM-DD]`:**
1. Default to today's date if no date given
2. Read all files in `~/projects/brain/progress/{date}/`
3. Display concatenated, grouped by session ID

**`decisions [project]`:**
1. List files in `~/projects/brain/decisions/` (or `decisions/{project}/` if specified)
2. Sort by modification time (newest first), show last 10
3. Display title + tags from frontmatter

**Natural language updates:**
If the user's input indicates a task update, fuzzy-match the task name against open tasks in `~/projects/brain/tasks/` and update accordingly using `sed -i ''`. Supported updates:
- **Status change** (e.g. "X is completed", "mark X done") → update `status:` field
- **Where stopped** (e.g. "stopped at X on task Y", "on Y: left off at X") → update `where_stopped:` field (add it if missing)
Confirm the change.

**Search term (any other argument):**
1. Run `grep -ril "{term}" ~/projects/brain/` to find matching files
2. For each match, show the filename and the matching line(s) with context
3. Limit to 20 results

**`next` / `priorities`:**
1. Read all open tasks: `grep -rl 'status: open' ~/projects/brain/tasks/`
2. Read the 10 most recent findings
3. Read today's progress files
4. Read active sessions: `ls ~/projects/brain/statuses/*.md` and filter for `status: active`
5. Analyze everything together and produce **top 3 recommendations** for what to work on next, considering:
   - Task priority and age
   - Momentum (what's already in progress today)
   - Gaps (important tasks with no recent progress)
   - Active sessions (don't recommend work that's already being done)
6. Format each recommendation with: what to do, why now, and which brain entries support it
