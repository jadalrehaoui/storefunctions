#!/bin/bash
# Start wrapper for the Storefunctions update/download server (port 8080).
# Mirrors api/start.sh: sets PATH, waits for internet, then exec's node.
# Runs under launchd label com.jadrehaoui.storefunctions-deploy.
export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH

DEPLOY_DIR="$HOME/storefunctions-deploy"

# Wait for internet connectivity before starting (the server syncs from GitHub).
until /usr/bin/curl -s --max-time 5 https://8.8.8.8 > /dev/null 2>&1; do
  echo "Waiting for internet connection..."
  sleep 5
done

cd "$DEPLOY_DIR"
# server.js loads ./.env via dotenv, so running from this dir is enough.
exec /usr/local/bin/node server.js
