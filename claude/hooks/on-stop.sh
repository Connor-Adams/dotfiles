#!/usr/bin/env bash
# Stop hook: checks for uncommitted changes in the current repo only
set -euo pipefail

# Only check the repo we're actually in
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0

DIRTY=$(git status --porcelain 2>/dev/null | head -10)
if [ -n "$DIRTY" ]; then
  REPO_NAME=$(basename "$REPO_ROOT")
  COUNT=$(echo "$DIRTY" | wc -l | tr -d ' ')
  echo "{\"systemMessage\": \"${REPO_NAME} has ${COUNT} uncommitted change(s)\"}"
fi
