## Git Commits (REQUIRED)

NEVER add a `Co-Authored-By` line to any commit message. Connor must be the sole author on all commits. Do not append any co-author trailers, attribution lines, or similar metadata.

## PR Merges (REQUIRED)

When merging PRs, default to **auto-merge with a merge commit** (`gh pr merge --auto --merge`). Do NOT squash. If the repo has `allow_auto_merge=false`, enable it first (`gh api -X PATCH repos/<owner>/<repo> -f allow_auto_merge=true`). If the repo lacks branch protection so `--auto` merges immediately, that's fine — Connor accepts the trade-off.

## Kindex (REQUIRED -- follow these in every session)

Kindex is a persistent knowledge graph that compounds knowledge across sessions. This is Connor's external memory — treat it as critical infrastructure, not optional logging.

### Session lifecycle
1. **Start**: `tag_start` (new work) or `tag_resume` (continuing). Always.
2. **Orient**: `search` the topic before touching code. Check what past sessions discovered.
3. **During**: capture as you go — don't batch, don't wait. See capture rules below.
4. **Segment**: `tag_update` with `action=segment` when switching topics.
5. **End**: `tag_update` with `action=end` and a summary.

### Capture trigger (CRITICAL — do not wait to be asked)
If you discover something that would be useful in a future session, `add` it IMMEDIATELY in the same response. Do NOT wait for the user to ask. Do NOT batch captures for later. The moment you think "that's interesting" or "I didn't expect that" or "someone should know this" — that is your trigger to `add` + `link`.

Concrete triggers — if any of these happen, capture RIGHT THEN:
- You find a bug, root cause, or unexpected behavior
- You discover a non-obvious code pattern, gotcha, or workaround
- You or the user make an architectural decision or trade-off
- You identify what a key file does or why it exists
- You find an API quirk, undocumented behavior, or edge case
- You solve a tricky TypeScript or type system problem
- You notice a performance issue (slow query, bundle size, build time)
- You encounter a new domain term or business concept
- You hit a question that can't be answered yet — `add` as question

### What to capture (use `add` or `learn` for bulk)
- **Patterns discovered**: non-obvious code patterns, gotchas, workarounds — `add` as concept
- **Decisions made**: architectural choices, why X over Y, trade-offs — `add` as decision
- **Key files**: what a file does, why it exists, its role in the system — `add` as concept with file path
- **Bug root causes**: what broke, why, and the fix — `add` as concept
- **Type system solutions**: tricky TypeScript patterns that solved real problems — `add` as concept
- **Performance findings**: slow queries, bundle sizes, build times — `add` as concept
- **API quirks**: undocumented behavior, edge cases in external services — `add` as concept
- **Questions**: open problems, things to investigate later — `add` as question
- **Domain terms**: project jargon, business concepts, recurring themes — `add` as concept

### Linking discipline (CRITICAL — the graph is useless without links)
- **After every `add` or `learn`**: immediately `link` new nodes to existing related ones
- **Before `learn`**: `search` first to find existing nodes to link TO
- **Node names must be specific**: "Hostaway cancellation policy Math.floor bug" not "Deep Dive"
- **Every session `add`**: link the concept to its session node and related concepts
- **Minimum**: every new node gets at least one link. Zero-link nodes are waste.
- Use edge types: `relates_to`, `depends_on`, `implements`, `contradicts`, `blocks`, `context_of`, `answers`, `supersedes`

### When to search
- **Before starting any work**: what does the graph already know about this?
- **Before adding**: avoid duplicates
- **When stuck**: `ask` the graph — past sessions may have solved this
- **When making decisions**: check if a similar decision was made before and why

### Bulk capture
- After reading a long file/output: `learn` to extract multiple concepts, then link each one
- After multi-step debugging: `learn` what happened and the resolution
- After completing a feature: `learn` the patterns and decisions involved

### Watches and reminders
- `watch_add` for ongoing concerns: flaky tests, unstable APIs, tech debt to revisit
- `remind_create` with `action`/`instructions` for time-based deferred tasks
- `suggest` periodically to find bridge opportunities in the graph

### What NOT to capture
- Trivial file reads, routine git ops, boilerplate
- Anything already in the graph
- Ephemeral state that only matters for the current session
- Vague or generic names — if you can't make it specific, don't add it
