#!/usr/bin/env bash
# PostToolUse hook: runs Biome check --write on edited/written files
set -euo pipefail

FILE=$(jq -r '.tool_response.filePath // .tool_input.file_path // ""')

# Only act on JS/TS files that exist
if echo "$FILE" | grep -qE '\.(ts|tsx|js|jsx)$' && [ -f "$FILE" ]; then
  cd "$(dirname "$FILE")" && npx --yes @biomejs/biome check --write "$FILE" 2>/dev/null || true
fi

exit 0
