#!/bin/sh
# Symlink .claude.json from volume to home directory if it exists
if [ -f /home/app/.claude/.claude.json ]; then
  ln -sf /home/app/.claude/.claude.json /home/app/.claude.json
fi

exec "$@"
