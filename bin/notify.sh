#!/usr/bin/env bash
# Usage: notify.sh "Title" "Message" ["tab-match"]
# Clicking the notification brings Warp to front and cycles to the tab matching tab-match.
TITLE="${1:-Claude}"
MSG="${2:-A Claude session needs attention}"
MATCH="${3:-}"

FOCUS_SCRIPT="$HOME/projects/brain/bin/warp-focus-tab.sh"

if command -v terminal-notifier &>/dev/null; then
  if [[ -n "$MATCH" ]]; then
    terminal-notifier \
      -title "$TITLE" \
      -message "$MSG" \
      -sound Ping \
      -execute "$FOCUS_SCRIPT '$MATCH'"
  else
    terminal-notifier \
      -title "$TITLE" \
      -message "$MSG" \
      -sound Ping \
      -activate com.googlecode.iterm2
  fi
else
  osascript -e "display notification \"$MSG\" with title \"$TITLE\" sound name \"Ping\""
fi
