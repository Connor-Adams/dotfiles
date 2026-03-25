#!/usr/bin/env bash
# PreCompact hook: reminds Claude to preserve key context before compaction
set -euo pipefail

cat <<'JSON'
{
  "hookSpecificOutput": {
    "hookEventName": "PreCompact",
    "additionalContext": "BEFORE COMPACTING: Capture any undocumented decisions, discoveries, or context to kindex NOW. After compaction you will lose the details. Specifically: (1) any architectural decisions or trade-offs discussed, (2) bug root causes discovered, (3) non-obvious patterns or gotchas found, (4) open questions that remain unresolved. Use kindex add+link for each. Then proceed with compaction."
  }
}
JSON
