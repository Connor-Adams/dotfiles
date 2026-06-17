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
- Worktree-based workflow (Conductor or git worktree)
- Time-boxed (hackathon, on-call)
- AI doing the heavy lifting; human steering scope

When NOT to use:
- Pure investigation, no expected fix
- New feature work — use feature-dev / brainstorming first
- Code refactor with no incident — use TDD

## Workflow

1. **Pull ticket + comments.** Truth often lives in a Slack-synced thread, not the ticket body. Capture the affected ID (booking/order/user), time window, and ops commentary.

2. **Get production-grade evidence before touching code.** These exact numbers will go in the PR body later.
   - [ ] Query Loki/Sentry on the actual incident ID
   - [ ] Capture event count
   - [ ] Capture time window
   - [ ] Capture the exact error message

3. **Dispatch parallel subagents WITH pre-loaded facts.** Otherwise they thrash on large repos and autocompact.
   - [ ] Pre-load verified facts: file paths, error message, log counts
   - [ ] Constrain file list to ≤7
   - [ ] Cap deliverable at ≤500 words
   - [ ] No "investigate" framing — give them the answer to verify, not the question

4. **Distinguish bug fix from new feature.** Bug fix = make broken code work as designed. New feature = change the design. When tempted to add a column / env var / policy / grace period: stop. If it isn't required to make the existing code correct, it's a follow-up, not part of this PR.

5. **Surgical fix in a worktree.** Branch off fresh main/dev. Run scoped tests + type-check before commit. `--force-with-lease` on amend. Match the project's commit-author convention.

6. **Bot feedback = code review, not auto-apply.** Cursor Bugbot / vuln scanners find real things AND stale things AND pre-existing things. Read each finding, decide validity, then act. Don't amend reflexively.

7. **Drive-by CI blockers handled inline.** If the file you touched has pre-existing violations the project's lint guards flag because the file is now in the diff (e.g., `as` casts, template-literal logger usage): fix them inline with the smallest defensible change. Don't expand scope; don't ignore.

8. **Honest scope boundaries in PR body.** List real follow-up bugs/features surfaced by the investigation that this PR does not fix. The user pain may be a policy decision the PR can't resolve.

9. **Production verification narrative.** The PR body becomes the verification artifact.
   - [ ] Cite the before-fix metric from step 2
   - [ ] Cite the after-fix observation
   - [ ] Map the delta directly to the fix's behavior change (e.g., "same input that produced N silent loops now produces 1 of each side-effect")

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

