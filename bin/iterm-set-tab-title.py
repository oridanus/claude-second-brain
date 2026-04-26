#!/usr/bin/env python3
"""Set iTerm2 tab title for the tab containing a given session ID."""
import asyncio
import sys
import iterm2

async def main(connection):
    session_id = sys.argv[1]
    title = sys.argv[2]
    app = await iterm2.async_get_app(connection)
    for window in app.terminal_windows:
        for tab in window.tabs:
            for session in tab.sessions:
                if session.session_id == session_id:
                    await tab.async_set_title(title)
                    return

iterm2.run_until_complete(main)
