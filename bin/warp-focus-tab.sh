#!/usr/bin/env bash
# Activate iTerm2 and jump directly to the tab whose session name contains the target string.
# Usage: warp-focus-tab.sh "match-string"
# (kept filename for backwards compat, but now targets iTerm2)
TARGET="${1:-}"
[[ -z "$TARGET" ]] && exit 0

osascript <<APPLESCRIPT
tell application "iTerm2"
  activate
  repeat with w in every window
    repeat with t in every tab of w
      if name of current session of t contains "$TARGET" then
        select t
        return "found"
      end if
    end repeat
  end repeat
end tell
APPLESCRIPT
