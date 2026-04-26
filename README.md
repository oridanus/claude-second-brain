# Claude Second Brain

A file-based persistent memory system for [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) sessions. Captures tasks, findings, decisions, and progress across sessions — survives compaction, terminal restarts, and machine reboots.

## Why

Claude Code sessions forget. CLAUDE.md is too coarse. Memory tools are ephemeral. The Second Brain is a flat directory of markdown files with YAML frontmatter that any Claude session — across any terminal tab or worktree — can read and write to. It's plain text, version-controllable, and grep-able.

## What you get

- **Tasks** — `tasks/{epoch}-{slug}.md`. Each tracks a real piece of work with `where_stopped` checkpoints so a new session can resume mid-thought.
- **Findings** — observations, gotchas, and patterns that don't belong in a commit message.
- **Decisions** — architecture/design records.
- **Progress** — append-only daily session logs, one file per session, grouped by date.
- **Goals** — weekly goals injected into every new session's context.
- **Statuses** — per-session liveness markers used by hooks and notifications.

Plus:
- 5 slash-command **skills** (`/brain`, `/brain-new-task`, `/brain-save`, `/brain-set-task`, `/brain-show-tasks`)
- **Hooks** that auto-link sessions to tasks at startup and prompt checkpoint updates every 10 minutes
- **macOS notifications** when a session stops with optional terminal-tab focus
- Optional integrations with **cmux** (Ghostty), **Warp**, and **iTerm2**

## Install

```bash
git clone https://github.com/<you>/claude-second-brain.git ~/projects/brain-src
cd ~/projects/brain-src
./install.sh
```

The installer:
1. Creates `~/projects/brain/` (the runtime directory) and copies `bin/` into it
2. Symlinks the 5 skills into `~/.claude/skills/`
3. Prints the snippet you need to paste into `~/.claude/settings.json` to enable hooks

> **Note:** Paths are hardcoded to `~/projects/brain` throughout. If you want a different location, fork or sed-replace before installing.

Optional macOS extras for nicer notifications:

```bash
brew install terminal-notifier
```

## Hooks (settings.json)

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [{ "type": "command", "command": "~/projects/brain/bin/session-start-hook.sh" }] }
    ],
    "PostToolUse": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "~/projects/brain/bin/status-hook.sh post_tool_use" }] }
    ],
    "Stop": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "~/projects/brain/bin/status-hook.sh stop" }] }
    ]
  }
}
```

See `docs/settings.json.example` for a complete file.

## Daily usage

```bash
/brain                    # dashboard: week goals, open task count, recent findings
/brain-new-task <title>   # create a new task
/brain-set-task <fuzzy>   # link the current Claude session to an existing task
/brain-show-tasks         # full open-task table with priorities + where-stopped
/brain-save task: ...     # save a task / finding: ... / decision: ... / progress: ...
/brain next               # top 3 recommendations for what to work on now
/brain <search-term>      # grep across the brain
/brain goals              # show the active week's goals
```

## How sessions get linked to tasks

When a Claude session starts, the SessionStart hook tries to match the current terminal/workspace to an open task by:

1. **iterm_session field** — exact match against the task's `iterm_session:` (cmux workspace ref or iTerm session ID)
2. **session_id field** — match against the prior linked session
3. **Workspace name** — case-insensitive fuzzy match against task titles

If matched, the session is "linked" — Claude sees the task title, priority, and `where_stopped` summary at startup, and the every-10-minute checkpoint reminder updates `where_stopped:` automatically.

## File layout

```
~/projects/brain/
├── bin/                  # hook + helper scripts
├── tasks/                # {epoch}-{slug}.md, status: open|done
├── findings/             # observations, optionally grouped by project
├── decisions/            # architecture/design records
├── progress/             # YYYY-MM-DD/{session-id}.md (append-only)
├── goals/                # weekly goals files
├── statuses/             # per-session liveness (auto-managed)
└── names.json            # session-id → task-title map (auto-managed)
```

## Frontmatter schema

Tasks:
```yaml
type: task
title: <string>
status: open | done
priority: high | medium | low
created: <ISO-8601>
session_id: <12-char>     # auto-set by hook
iterm_session: <ref>      # auto-set by hook (e.g. "workspace:1")
tags: [list]
where_stopped: "<string>" # auto-updated by checkpoint hook
tracker_url: <url>        # optional issue tracker link
```

Goals:
```yaml
type: weekly-goals
week_start: <YYYY-MM-DD>
week_end: <YYYY-MM-DD>
status: active | archived
```

## Optional terminal integrations

- **cmux (Ghostty):** `bin/cmux-workspaces.sh` creates a workspace per open task; tab titles auto-rename to task name on link
- **Warp:** `bin/warp-focus-tab.sh` cycles to a tab matching a name (used by notifications)
- **iTerm2:** `bin/iterm-set-tab-title.py` sets the current tab title via Python API

If you don't use any of these, the brain still works — just without the auto-tab-titling.

## License

MIT — see `LICENSE`.
