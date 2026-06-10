#!/bin/sh
# Symlink credentials from volume to home directory if they exist
if [ -f /home/app/.claude/.credentials.json ]; then
  chmod 600 /home/app/.claude/.credentials.json
fi

exec "$@"
