# Architecture

## Components

```
┌─────────────────────────────────────────────────────────────┐
│  Claude Code session                                        │
│  ┌────────────────────┐    ┌─────────────────────────────┐  │
│  │ Slash commands     │    │ Hooks (settings.json)       │  │
│  │ /brain, /brain-*   │    │ SessionStart, PostToolUse,  │  │
│  │ (skills/)          │    │ Stop → bin/*-hook.sh        │  │
│  └────────┬───────────┘    └────────────┬────────────────┘  │
│           │ read/write                  │ read/write        │
└───────────┼─────────────────────────────┼───────────────────┘
            ▼                             ▼
   ┌────────────────────────────────────────────┐
   │  ~/projects/brain/                         │
   │  tasks/  findings/  decisions/  progress/  │
   │  goals/  statuses/  names.json             │
   └────────────────────────────────────────────┘
```

## Hook flow

### SessionStart
1. Read `cmux identify` (if available) to get current workspace ref.
2. Scan all open tasks; try three matchers in order:
   - exact `iterm_session` match
   - `session_id` prefix match
   - case-insensitive workspace-name vs task-title match
3. If matched: write current short-id back into the task, append to `names.json`, optionally rename the cmux workspace, and emit a `[Brain Task Linked]` block to the session context.
4. If unmatched: emit the open-task list and instruct Claude to fuzzy-pick one.
5. In both cases, append the active week's goals (from `goals/`) to the session context.

### PostToolUse
- Touch `statuses/{id}.md` with `status: active`.
- Every 10 minutes, emit a `[Brain Checkpoint Reminder]` instructing Claude to update the linked task's `where_stopped:` field silently.

### Stop
- Touch `statuses/{id}.md` with `status: done`.
- Append `## HH:MM - Session stopped` to today's `progress/{date}/{id}.md`.
- If the session was linked to a task, append `Where stopped: <text>` from the task's frontmatter.
- Trigger `notify.sh` (macOS notification) if configured.

## Why files instead of a database

- Plain text → grep, version control, diff, review in any editor.
- Frontmatter → structured queries via `awk`/`yq` without a runtime.
- Filesystem → no daemon, no port, nothing to forget to start.
- Multiple Claude sessions can read/write concurrently because each session writes its own progress file (epoch-slug filenames avoid collisions).

## Concurrency model

- Tasks are read by many, written by few (the linked session).
- Progress files are append-only and partitioned by session ID.
- Status files are last-writer-wins (only one session per ID anyway).
- `names.json` is read-modify-write but contention is rare; corruption recovery is trivial (delete the file, hooks rebuild it).

## Optional integrations

| File | What it does | Required |
|------|---|---|
| `bin/cmux-workspaces.sh` | Creates one cmux workspace per open task | cmux |
| `bin/warp-focus-tab.sh` | Cycles to a Warp tab matching a name | Warp |
| `bin/iterm-set-tab-title.py` | Sets iTerm tab title via Python API | iTerm2 + python3 |
| `bin/notify.sh` | macOS notification with optional terminal focus | macOS (+ `terminal-notifier` for richer notifs) |
| `bin/statusline.sh` | Custom Claude Code statusline showing linked task | Claude Code statusline support |
