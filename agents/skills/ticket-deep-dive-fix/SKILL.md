---
name: ticket-deep-dive-fix
description: Use when a Linear/Jira ticket reports an issue with an existing feature (bug, regression, value-divergence, perf, data quality, customer complaint) and the work runs ticket-to-PR end-to-end. Trace the issue across every subsystem it touches before proposing a fix; ground evidence in production data (Loki/Grafana/Sentry) when available, code archaeology + repro when not. Not for new feature work — use feature-dev/brainstorming. Choose this over systematic-debugging when a ticket exists and the fix needs to ship as a PR.
---

# Ticket Deep Dive Fix

## Overview

Incident-response-team workflow applied to any ticket about an existing feature. Treat the ticket as a symptom, not a diagnosis. Trace every subsystem it could touch in parallel, converge on the real failure mode, then ship a surgical fix. The proof of the issue and the proof of the fix come from the same evidence.

**Core principle**: find the real failure across the subsystems touched first; let it constrain the fix.

## When to use

- Ticket about an existing feature (bug, regression, perf, data divergence, customer complaint)
- Work runs ticket → merged PR
- Worktree-based workflow (Conductor or git worktree)
- Human steering scope; AI doing the heavy lifting

When NOT to use:
- New feature work — use `superpowers:brainstorming` then `feature-dev:feature-dev`
- Pure debugging with no ticket and no PR target — use `superpowers:systematic-debugging`
- Refactor with no incident — use `superpowers:test-driven-development`

This skill composes with siblings; it does not replace them. Invoke `superpowers:dispatching-parallel-agents` for fanouts, `superpowers:using-git-worktrees` for the workspace, `superpowers:verification-before-completion` before claiming done.

## Workflow

### 1. Pull ticket context
Truth often lives in a Slack-synced thread, linked PR, or recent incident — not the ticket body. Capture:
- Affected ID(s) (booking/order/user)
- Time window and recent deploys around it
- Ops commentary, "third one this week" pattern signals
- Linked tickets, prior fixes that may have regressed

### 2. Map subsystem touchpoints (BEFORE evidence-gathering)
Hypothesize which boundaries the issue could cross. List them.

For a value-divergence bug: serializer → external sync → compute → cache → display → db invariants.
For a perf complaint: query plan → cache hit rate → queue depth → external API latency → bundle size.
For a regression: recent deploys → changed files → behavior diff at the boundary that changed.

This list is the spec for step 3's fanout. If you can't list 3+ candidate boundaries, the ticket isn't ambiguous enough to need this skill — drop to direct debugging.

### 3. Triage fanout (read-only)
Dispatch parallel subagents, one per subsystem hypothesis. Each:
- ≤3 files
- Returns "evidence found / not found / inconclusive" — NOT a fix
- Pre-loaded with the affected ID, time window, and the specific boundary to inspect

Triage subagents ASK questions ("does this serializer round-trip the policy_version field?"). Verification subagents (step 6) verify ANSWERS. Don't conflate the two roles.

### 4. Converge on root cause
Read the fanout reports. Look for the first boundary where the value or behavior disagrees with the booking-time / contract-time / spec-time expectation. If the fanout doesn't narrow:
- Sharpen the boundary list and re-fan; don't jump to a fix on a 50/50 hypothesis
- If still ambiguous, write the ambiguity into the ticket as a comment and ask the human

### 5. Gather evidence on the chosen hypothesis
This is the data that goes in the PR body later.
- Production-grade when available: query Loki/Sentry on the incident ID; capture event count, time window, exact error or value-divergence
- Code-grade when not: minimal local repro, `git blame` on the suspect boundary, recent deploys touching the file
- For value-divergence bugs (no exception thrown): instrument the data flow — log the value as it crosses each boundary; the bug is at the first boundary where it disagrees with the contract

### 6. Verification fanout
NOW dispatch parallel subagents with pre-loaded answers to verify.
- ≤7 files each
- ≤500 words deliverable
- "Confirm that line X behaves as Y" — not "investigate Z"
- This is the step that wants "give answers, not questions"

### 7. Classify the fix
Four classes — don't conflate them:
1. **Pure bug fix** — make broken code behave as designed. No schema/env/policy changes.
2. **Data-model-invariant repair** — existing model can't represent the contract (e.g., needing `policyVersionId` to pin policy at booking time). Schema change is justified; flag explicitly in PR body.
3. **Product/policy decision** — not yours to make. Surface to the human; the PR may not be able to close the user pain alone.
4. **New feature** — out of scope. File a follow-up; do not bundle.

If you typed `addColumn`, `migration`, or `new env var`: which class is this? If class 2, proceed with paper trail. If class 1, undo the typing.

### 8. Surgical fix in a worktree
- Branch off fresh dev/main (rebase, never merge)
- Worktree at `~/conductor/workspaces/<repo>/<city>/`
- Scoped tests + type-check pre-commit
- `--force-with-lease` on amend
- Match the project's commit-author convention (Connor sole author; no co-author trailers)

### 9. Bot feedback = code review, not auto-apply
Cursor Bugbot, vuln scanners, lint guards find real things AND stale things AND pre-existing things. Read each finding, decide validity, then act. Don't amend reflexively.

### 10. Drive-by CI blockers handled inline
If the file you touched has pre-existing violations the project's lint guards flag because the file is now in the diff (`as` casts, template-literal logger usage, `process.env` outside `@wos/env`): fix inline with the smallest defensible change. Don't expand scope; don't ignore.

### 11. Honest scope boundaries in PR body
List real follow-up bugs/features surfaced by the investigation that this PR does not fix. The user pain may be a policy decision or out-of-scope feature; say so.

### 12. Evidence-grounded verification narrative
The PR body is the verification artifact.
- Cite the before-state from step 5 (count, error, divergence value)
- Cite the after-state observation (test result, repro disappearance, predicted production delta)
- Map the delta directly to the fix's behavior change
- If post-deploy metric isn't yet available, cite the *predicted* delta + the exact query that will confirm + a follow-up reminder

### 13. Self-review before requesting human review
Run `pr-review-toolkit:review-pr` on the PR before flagging it for human review. Treat its findings the same as bot feedback in step 9 — read each, decide validity, then act. Address durability/correctness items; defer pure-taste suggestions. Document any deferrals in the PR body.

## Anti-patterns

| Mistake | Reality |
|---|---|
| "Add a notification — fixes the user pain" | Symptomatic. There's already a path; figure out why it didn't fire. |
| "While I'm here, also fix grace period + refund + ..." | Each follow-up is its own decision; bundle = unmergeable. |
| "Let an agent investigate the whole bug" | Agents thrash on huge repos. Pre-load facts; cap files; cap output; split triage from verification. |
| "Bugbot flagged it; amend the fix" | Assess validity first. Bot findings can be stale, pre-existing, or false. |
| "`satisfies` fixes any `as` complaint" | `satisfies` checks conformance, not narrowing. Union narrowing needs a runtime check. |
| "Diff is obvious, skip the test" | Untested orchestration paths bite. Either test the load-bearing claim or call out the gap honestly. |
| "Skipping triage subagents because the skill said 'don't ask questions'" | That guidance is for step 6, not step 3. Triage asks questions; verification confirms answers. |
| "addColumn must be wrong because the skill flagged migrations" | Not if it's a data-model-invariant repair (class 2). Paper-trail it; proceed. |

## Red flags — STOP and reset scope

- You jumped from step 1 to step 8 without a fanout
- You're four files into the change and the original ticket is still untouched
- The PR description has a "while we're at it" section
- A subagent is asking for facts you already know
- You're amending bot feedback without reading what changed
- You typed `addColumn` and haven't classified the fix yet (step 7)
- The fanout came back inconclusive and you picked the most likely hypothesis anyway
