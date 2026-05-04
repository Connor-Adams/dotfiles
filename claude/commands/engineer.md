`/engineer` is your **autonomous engineering pipeline** skill — a structured, gated process for shipping production-grade code from a Linear ticket, GitHub issue, or plain-language request.

## The pipeline

`Transmogrifier → Constrain → Preflight → Pact (plan-only) → Implement → Advocate → Kindex → __DONE__ gate`

## What each phase does

1. **Session Setup** — activate kindex `engineer` mode, switch `gh` auth (jmc-wander vs jmcentire), create `/tmp/engineer-<task-id>/`
2. **Context Gathering** — fetch Linear/GitHub ticket, search kindex, read repo `CLAUDE.md` + `.claude/rules/` + `REVIEW.md`, check if codebase is ingested
3. **Transmogrifier** — normalize prompt register to technical (avoids ~19% accuracy loss on casual register)
4. **Constrain** — synthesize `prompt.md` + `constraints.yaml` (hard/soft constraints, scope, acceptance + done criteria)
5. **Preflight** — write `preflight.yaml` with self-constraints (no_stubs=block, error_handling=block, etc.) and an explicit Plan B
6. **Pact (plan-only)** — generate design + decomposition + contracts + tests; also runs `pact assess` for structural friction
7. **Implementation** — *you* write the code against the contracts. Linear branch name required. No stubs/mocks/TODOs. Errors, logging, events, monitoring, alerting, security, privacy all in-scope per __DONE__
8. **Advocate** — six-persona adversarial review (Red Team, Adversarial, Sage, User, SME, Good Friend). Critical/high must be fixed
9. **Kindex** — `kin ingest --adapter code` (ctags + tree-sitter), capture decisions/constraints/watches
10. **__DONE__ gate** — explicit checklist (code completeness, error handling, logging, monitoring, security, privacy, testing, docs). No PR until it passes
11. **PR & CI** — Wander repos labeled `work-in-progress` (never `ready-to-review`); watch CI with `gh pr checks --watch`
12. **Completion** — `tag_update action=end`, clean up `/tmp/`, report to you

## Key principles

- **__DONE__ ≠ "compiles and tests pass."** It's "on-call tomorrow, no pages; auditor finds no gaps; pentester finds no easy wins."
- **Plan B** triggers after 3 failed attempts or scope expansion — stop, document, fall back to MVP, ask before proceeding.
- **If a tool isn't installed, do the phase manually** — the phase matters, not the tool.
- **Process tracking via TaskCreate** — 12 tasks, marked done as each phase completes.

## Input

`/engineer INT-936` (Linear), `/engineer <gh-issue-url>`, or `/engineer <plain description>`. Asks if no input given.

It's heavyweight — designed for shipping a real ticket end-to-end, not for quick edits.
