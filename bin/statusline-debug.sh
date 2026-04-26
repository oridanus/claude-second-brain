#!/usr/bin/env bash
# Debug: log everything about the statusline invocation
exec 2>/tmp/statusline-debug.log
echo "=== $(date) ===" >&2
echo "PID=$$, PPID=$PPID" >&2
echo "TTY=$(tty 2>/dev/null || echo none)" >&2
echo "PS TTY=$(ps -o tty= -p $$ 2>/dev/null)" >&2
echo "STDIN:" >&2
if read -t 1 line; then
  echo "$line" >&2
  echo "test output"
else
  echo "(no stdin)" >&2
  echo "test output"
fi
