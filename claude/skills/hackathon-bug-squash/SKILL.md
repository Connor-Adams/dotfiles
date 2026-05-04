---
name: hackathon-bug-squash
description: Use when working a real production bug end-to-end under time pressure (Linear/Jira ticket → green PR), with access to production observability (Loki/Grafana/Sentry) and a worktree workflow. Especially when AI is the primary doer and a human is steering scope.
---

# Hackathon Bug Squash

## Overview
Surgical bug-fix workflow from incident ticket to ready-for-review PR. Ground every decision in real production data, not synthetic repros. The proof of the bug and the proof of the fix come from the same observability tooling.

Core principle: **find the real failure in production data first; let it constrain the fix.**

## When to use
- Real production incident with a ticket
- Production observability access (Loki/Grafana/Sentry, or equivalent)
- Worktree-based workflow (Conductor, git worktree)
- Time-boxed (hackathon, on-call)
- AI doing the heavy lifting; human steering scope

When NOT to use:
- Pure investigation, no expected fix
- New feature work — use feature-dev / brainstorming first
- Code refactor with no incident — use TDD

## Workflow

1. **Pull ticket + comments.** Truth often lives in a Slack-synced thread, not the ticket body. Capture the affected ID (booking/order/user), time window, and ops commentary.

2. **Get production-grade evidence before touching code.** Query Loki/Sentry on the actual incident ID. Quantify the failure: how many events, over what window, with what message. These exact numbers will go in the PR body later.

3. **Dispatch parallel subagents WITH pre-loaded facts.** Don't ask agents to "investigate" — give them the verified facts (file paths, error message, log counts), a tight file list (≤7), and a deliverable cap (≤500 words). Otherwise they thrash on large repos and autocompact.

4. **Distinguish bug fix from new feature.** Bug fix = make broken code work as designed. New feature = change the design. When tempted to add a column / env var / policy / grace-period: stop. If it isn't required to make the existing code correct, it's a follow-up, not part of this PR.

5. **Surgical fix in a worktree.** Branch off fresh main/dev. Run scoped tests + type-check before commit. `--force-with-lease` on amend. Match the project's commit-author convention.

6. **Bot feedback = code review, not auto-apply.** Cursor Bugbot / vuln scanners find real things AND stale things AND pre-existing things. Read each finding, decide validity, then act. Don't amend reflexively.

7. **Drive-by CI blockers handled inline.** If the file you touched has a pre-existing `as` cast / template-literal logger / etc. that the GHA flags because the file is now in the diff: fix it inline with the smallest defensible change. Don't expand scope; don't ignore.

8. **Honest scope boundaries in PR body.** List real follow-up bugs/features the investigation surfaced but this PR does not fix. The user pain may be a policy decision the PR can't resolve.

9. **Production verification narrative.** Map the evidence directly to the fix's behavior change. "Same input that produced 33 silent loops now produces 1 of each side-effect." Quote real metrics. The PR body becomes the verification artifact.

## Anti-patterns

| Mistake | Reality |
|---|---|
| "Add a notification — fixes the user pain" | Symptomatic fix. There's already a notification path; figure out why it didn't fire. |
| "While I'm here, also fix grace period + refund + ..." | Scope creep. Each follow-up is its own decision; bundle = unmergeable. |
| "Let an agent investigate the whole bug" | Agents thrash on huge repos. Pre-load proven facts; give ≤7 files; cap output. |
| "Bugbot flagged it; amend the fix" | Assess validity first. Bot findings can be stale, pre-existing, or false. |
| "`satisfies` fixes any `as` complaint" | `satisfies` checks conformance, not narrowing. Union narrowing needs a runtime check. |
| "Diff is obvious, skip the test" | An untested orchestration path will bite. Either test the load-bearing claim or call out the gap honestly in the PR body. |

## Red flags — STOP and reset scope

- You just typed `addColumn`, `migration`, or `new env var` for a "bug fix"
- You're four files into the change and the original bug is still untouched
- The PR description has a "while we're at it" section
- A subagent is asking for facts you already know
- You're amending bot feedback without reading what changed
- You're sending the same status three times in a loop with no human ack

## Real-world example

MARK-6859 (HNHL second-payment cron storm at Wander):
- Linear ticket + Slack comments → identified booking ID `cmf1hzvqk00pild2gjpr71knn`
- Loki query → **33 occurrences** of `[HNHL]{captureLater} Could not set next auto-capture date` for invoice `LT8G5ICS-0006` between 2025-11-30 08:00 UTC and 15:00 UTC
- Code trace → `captureLater` threw before email-send block + DB write, leaving `nextAutoCapture` null and the cron looping
- Fix: persist a sentinel + run side-effects before throw; throw preserved for queue/Sentry
- PR body cited the exact 33 occurrences as the "verifiable problem"; same inputs now produce 1 of each side-effect

What didn't work the first time: an Explore subagent dispatched without pre-loaded facts thrashed on the huge wander repo and was abandoned. Lesson codified in step 3.

## Testing status

This skill was distilled from a single session, **not** subjected to the formal RED-GREEN-REFACTOR cycle that `superpowers:writing-skills` mandates. The patterns are real (each one is a verbatim correction the human applied to the AI in that session). Suggested follow-up: run baseline pressure scenarios on a different repo / different ticket to confirm the workflow generalizes.
