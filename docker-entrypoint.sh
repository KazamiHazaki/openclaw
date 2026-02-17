#!/bin/sh
set -e

echo "Fixing permissions for /home/node/.openclaw..."

mkdir -p /home/node/.openclaw
chown -R node:node /home/node/.openclaw

echo "Starting as node user..."

exec gosu node "$@"
