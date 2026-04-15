#!/bin/sh
# Commit + push workflow.
#
# Edit COMMIT_MESSAGE below, then run: ./scripts/push.sh
# - Stages everything tracked + new files
# - Creates a single commit with the message below
# - Pushes (the pre-push hook will run scripts/release.js to bump the version)

set -e

COMMIT_MESSAGE="Inspecting items now allow to go back to list, and inspecting 1 item now allow to print label. Corrected the cierre sitsa where the print says a different amount of the screen, now more consistent. Dashboard totals was off, now it's good."

if [ "$COMMIT_MESSAGE" = "<edit me>" ]; then
  echo "✗ Edit COMMIT_MESSAGE in scripts/push.sh first."
  exit 1
fi

cd "$(git rev-parse --show-toplevel)"

# Stage everything (tracked changes + new files).
git add -A

# Bail if there's nothing to commit.
if git diff --cached --quiet; then
  echo "Nothing to commit."
  exit 0
fi

git commit -m "$COMMIT_MESSAGE"
git push
