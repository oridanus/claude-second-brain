---
name: brain-show-tasks
description: Show open tasks from the second brain
user_invocable: true
---

# Brain Show Tasks

List open tasks from `~/projects/brain/tasks/`.

## Instructions

1. Find all open task files: `grep -rl 'status: open' ~/projects/brain/tasks/`
2. For each file, read `title`, `priority`, `created`, and `where_stopped` from frontmatter
3. Display as a table sorted by priority (high > medium > low), then by date
4. The `where_stopped` column shows a short note of last progress — display "—" if not set
