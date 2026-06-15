---
name: cashflow-fleet-status
description: Use when Connor says "cashflow fleet status", "check cashflow workers", "what are my cashflow workers doing", "are any cashflow PRs stuck", or "/cashflow-fleet-status" — a READ-ONLY snapshot of the autonomous-loop fleet: active worktrees, open claude/issue-* PRs, their CI/merge state, and which are orphaned (untended). Reports only; never spawns workers or fixes PRs (that is cashflow-tackle's job). Not for non-cashflow repos.
---

# Cashflow — Fleet Status (read-only)

## Overview

A one-shot health snapshot of the `cashflow-tackle` fleet. Answers "what are my
workers doing, and is anything stuck?" without touching anything. To actually FIX
orphans, run `cashflow-tackle` — it owns dispatch + the orphan sweep.

## When to use

- Connor asks for fleet/worker status, or whether any cashflow PRs are stuck.
- Triggers: "cashflow fleet status", "check cashflow workers", "are cashflow PRs stuck", `/cashflow-fleet-status`.

When NOT to use:
- Connor wants to START or FIX work → `cashflow-tackle`.
- A specific single issue → `cashflow-issue-worker`.
- Non-cashflow repo.

## Source of truth

Read `/Users/connoradams/Developer/cashflow/.claude/conventions.md` for the repo path
and GitHub Project board IDs. Do not restate those facts here.

## Steps

1. **Worktrees** (from the main checkout):

   ```bash
   git -C /Users/connoradams/Developer/cashflow worktree list
   ```

2. **Open worker PRs** with CI + merge state:

   ```bash
   gh pr list --repo Connor-Adams/cashflow --state open --search "head:claude/issue-" \
     --json number,title,headRefName,mergeable,autoMergeRequest,statusCheckRollup,updatedAt
   ```

3. **Join** worktree ↔ PR by branch name (`headRefName` vs the branch checked out in
   each worktree from step 1).

4. **Classify each PR** (same rules as `cashflow-tackle` §9 orphan sweep). Mark
   **orphan** if ANY:
   - `mergeable == "CONFLICTING"` (needs rebase)
   - `autoMergeRequest == null` (auto-merge off / disengaged)
   - any `statusCheckRollup` conclusion `== "FAILURE"` and `updatedAt` > ~10 min ago
   - `updatedAt` > ~30 min ago and not merged (stale)

5. **Print one compact table**: PR# · issue# · branch · worktree? · CI (pass/fail/pending)
   · auto-merge? · orphan-reason · age. Sort orphans first.

6. If any orphans: end with one line — "N orphan(s); run `cashflow-tackle` to sweep."
   Otherwise: "fleet healthy."

## Anti-patterns

- ❌ Spawning workers or babysitters — this skill is read-only. That's `cashflow-tackle`.
- ❌ Force-pushing, re-arming auto-merge, or resolving conflicts here.
- ❌ Restating board IDs / repo paths instead of reading `conventions.md`.
- ❌ Polling in a loop — this is a one-shot snapshot. Re-invoke to refresh.
