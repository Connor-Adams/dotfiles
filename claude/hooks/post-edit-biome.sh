#!/usr/bin/env bash
# PostToolUse hook: auto-formats edited/written files using the repo's formatter.
# Detects Biome vs Prettier by walking up from the file to find a config.
set -euo pipefail

FILE=$(jq -r '.tool_response.filePath // .tool_input.file_path // ""')

# Only act on JS/TS files that exist
if ! echo "$FILE" | grep -qE '\.(ts|tsx|js|jsx)$' || [ ! -f "$FILE" ]; then
  exit 0
fi

# Walk up from file to find which formatter config exists
find_config() {
  local dir="$1"
  local name="$2"
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/$name" ]; then
      echo "$dir/$name"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

DIR=$(dirname "$FILE")

# Check for Biome first (biome.json or biome.jsonc)
if find_config "$DIR" "biome.json" >/dev/null 2>&1 || find_config "$DIR" "biome.jsonc" >/dev/null 2>&1; then
  cd "$DIR" && npx --yes @biomejs/biome check --write "$FILE" 2>/dev/null || true
  exit 0
fi

# Check for Prettier (.prettierrc, .prettierrc.js, .prettierrc.json, prettier.config.*)
for cfg in .prettierrc .prettierrc.js .prettierrc.cjs .prettierrc.json .prettierrc.yaml .prettierrc.yml .prettierrc.toml prettier.config.js prettier.config.cjs prettier.config.mjs; do
  if find_config "$DIR" "$cfg" >/dev/null 2>&1; then
    cd "$DIR" && npx --yes prettier --write "$FILE" 2>/dev/null || true
    exit 0
  fi
done

# No formatter config found — skip
exit 0
