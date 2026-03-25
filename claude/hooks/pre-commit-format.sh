#!/usr/bin/env bash
# Pre-commit formatter hook for Claude Code
# Detects the repo's formatter and runs it on staged files before git commit

set -euo pipefail

# Read stdin JSON and extract the bash command
CMD=$(jq -r '.tool_input.command // ""' 2>/dev/null)

# Only act on git commit commands (not amend-only, not git commit --allow-empty, etc.)
if ! echo "$CMD" | grep -qE '^\s*git\s+commit\b'; then
  exit 0
fi

# Get repo root (bail if not in a git repo)
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0

# Get staged files (exclude deleted files)
STAGED_FILES=$(git diff --cached --name-only --diff-filter=d 2>/dev/null) || exit 0
if [ -z "$STAGED_FILES" ]; then
  exit 0
fi

cd "$REPO_ROOT"

# Detect formatter and build command
FORMAT_CMD=""
FORMAT_NAME=""

if [ -f "biome.json" ] || [ -f "biome.jsonc" ]; then
  FORMAT_NAME="Biome"
  # Detect package manager
  if [ -f "pnpm-lock.yaml" ]; then
    FORMAT_CMD="pnpm exec biome check --write --no-errors-on-unmatched"
  elif [ -f "yarn.lock" ]; then
    FORMAT_CMD="yarn exec biome check --write --no-errors-on-unmatched"
  elif [ -f "bun.lockb" ] || [ -f "bun.lock" ]; then
    FORMAT_CMD="bunx @biomejs/biome check --write --no-errors-on-unmatched"
  else
    FORMAT_CMD="npx @biomejs/biome check --write --no-errors-on-unmatched"
  fi
elif [ -f ".prettierrc" ] || [ -f ".prettierrc.json" ] || [ -f ".prettierrc.js" ] || [ -f ".prettierrc.cjs" ] || [ -f ".prettierrc.mjs" ] || [ -f ".prettierrc.yaml" ] || [ -f ".prettierrc.yml" ] || [ -f ".prettierrc.toml" ] || [ -f "prettier.config.js" ] || [ -f "prettier.config.cjs" ] || [ -f "prettier.config.mjs" ]; then
  FORMAT_NAME="Prettier"
  if [ -f "pnpm-lock.yaml" ]; then
    FORMAT_CMD="pnpm exec prettier --write --ignore-unknown"
  elif [ -f "yarn.lock" ]; then
    FORMAT_CMD="yarn exec prettier --write --ignore-unknown"
  elif [ -f "bun.lockb" ] || [ -f "bun.lock" ]; then
    FORMAT_CMD="bunx prettier --write --ignore-unknown"
  else
    FORMAT_CMD="npx prettier --write --ignore-unknown"
  fi
elif [ -f "Cargo.toml" ]; then
  FORMAT_NAME="rustfmt"
  FORMAT_CMD="cargo fmt --"
elif [ -f "pyproject.toml" ] && grep -qE '\[tool\.ruff\]' pyproject.toml 2>/dev/null; then
  FORMAT_NAME="Ruff"
  FORMAT_CMD="ruff format"
elif [ -f "pyproject.toml" ] && grep -qE '\[tool\.black\]' pyproject.toml 2>/dev/null; then
  FORMAT_NAME="Black"
  FORMAT_CMD="black"
elif [ -f "go.mod" ]; then
  FORMAT_NAME="gofmt"
  FORMAT_CMD="gofmt -w"
elif [ -f ".clang-format" ]; then
  FORMAT_NAME="clang-format"
  FORMAT_CMD="clang-format -i"
fi

# No formatter detected — check package.json for prettier as dependency
if [ -z "$FORMAT_CMD" ] && [ -f "package.json" ]; then
  if jq -e '.devDependencies.prettier // .dependencies.prettier' package.json >/dev/null 2>&1; then
    FORMAT_NAME="Prettier"
    if [ -f "pnpm-lock.yaml" ]; then
      FORMAT_CMD="pnpm exec prettier --write --ignore-unknown"
    elif [ -f "yarn.lock" ]; then
      FORMAT_CMD="yarn exec prettier --write --ignore-unknown"
    else
      FORMAT_CMD="npx prettier --write --ignore-unknown"
    fi
  fi
fi

if [ -z "$FORMAT_CMD" ]; then
  exit 0
fi

# Filter staged files to only those that exist and pass to formatter
FILES_TO_FORMAT=""
while IFS= read -r file; do
  [ -f "$file" ] && FILES_TO_FORMAT="$FILES_TO_FORMAT $file"
done <<< "$STAGED_FILES"

if [ -z "$FILES_TO_FORMAT" ]; then
  exit 0
fi

# Run the formatter
$FORMAT_CMD $FILES_TO_FORMAT 2>/dev/null || true

# Re-stage any files that were formatted
for file in $FILES_TO_FORMAT; do
  if [ -f "$file" ]; then
    git add "$file" 2>/dev/null || true
  fi
done

# Output context for Claude
echo "{\"hookSpecificOutput\": {\"hookEventName\": \"PreToolUse\", \"additionalContext\": \"Ran $FORMAT_NAME on staged files before commit.\"}}"
