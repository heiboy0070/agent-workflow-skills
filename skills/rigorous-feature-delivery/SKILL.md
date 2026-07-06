---
name: rigorous-feature-delivery
description: Use for substantial implementation tasks, especially multi-repo or risky feature work that needs isolated worktrees, a tracked plan, SQL-as-file review, staged commits, explicit tests, blocked-test documentation, API docs, review/red-team, and Chinese commit messages.
---

# Rigorous Feature Delivery

Use this skill to execute large feature, refactor, or migration work end to end. Prefer it when the task spans multiple repositories, touches auth/data/schema behavior, requires deployment safety, or the user asks for a detailed plan and acceptance criteria.

## Workflow

1. Establish scope from local code before asking questions.
   - Inspect the relevant repos, routes, services, schema files, tests, and existing docs.
   - Ask only when the answer cannot be discovered and a wrong assumption would be risky.
   - State assumptions explicitly in the tracking document.

2. Isolate the work.
   - Create a branch from the repo's mainline branch.
   - Use worktrees for multi-repo or high-risk changes.
   - Record original repo paths, worktree paths, branch names, and dirty baseline status.
   - Do not revert unrelated user changes.

3. Create and maintain a progress document.
   - Put the document in the primary repo unless the user asks otherwise.
   - Include objective, constraints, repo paths, phases, files changed, tests, blocked tests, review notes, deployment plan, rollback plan, and acceptance criteria.
   - Update it during the work, not only at the end.

4. Treat database changes as reviewable artifacts.
   - Never execute production or project SQL unless the user explicitly asks and approves.
   - Add migration or SQL files with clear comments and execution notes.
   - Document which tests remain blocked until SQL is manually reviewed and executed.

5. Implement in reviewable slices.
   - Follow existing code patterns and keep unrelated refactors out.
   - Add feature flags for risky behavior when old behavior must continue during deployment.
   - Prefer backward-compatible schema and response changes.
   - For auth/token work, document token ownership, expiry, revocation, and fallback behavior.

6. Verify with real commands.
   - Before starting local services, state each port and which backend it represents.
   - Keep frontend base URL variables mapped to their real backend roles; do not point unrelated PHP/V2/Node variables to the same address unless explicitly doing a labeled mock-only test.
   - Run focused tests for new behavior.
   - Run build/lint/typecheck for touched services where available.
   - If full suites fail on baseline, document the baseline failures and run scoped tests.
   - If runtime, database, or table prerequisites are missing, create a blocked-test Markdown file with exact unblock steps and acceptance criteria.
   - Stop any local dev server, mock API, browser session, or background process started for the test when the test finishes, fails, or is interrupted.

7. Write handoff documentation.
   - For API work, create an API document with endpoint purpose, request examples, response examples, auth requirements, feature flags, errors, and notes.
   - For deployment-risk work, include rollout order, smoke tests, rollback switch, and what is not guaranteed.

8. Review and red-team before completion.
   - Invoke `rigorous-delivery` for this gate; do not replace it with self-review.
   - Follow `rigorous-delivery` Iron rule 7: dispatch one independent normal reviewer subagent and one independent adversarial red-team subagent.
   - `superpowers:requesting-code-review` may only supplement the normal review. It does not satisfy the red-team requirement and cannot replace `rigorous-delivery`.
   - If `rigorous-delivery` is unavailable but `superpowers:requesting-code-review` is available, use it for the normal review and still run a separate adversarial red-team review.
   - The review must check regressions, missing permission checks, deployment ordering, table-not-found behavior, token/user mismatch, rollback behavior, data-access/performance risk, and untested paths.
   - Fix findings or document residual risks with evidence.
   - If dedicated review/red-team skills or subagents are unavailable, record that limitation in the tracking document and final report; label the result as a local fallback, not as the required independent review.

9. Commit by functional slice.
   - Commit major pieces separately so they can be reverted independently.
   - Use Chinese commit subject/body and include `feat` or `fix` when required by the repo or user.
   - Mention verification or deployment-safety details in commit bodies when useful.

10. Final report.
   - Include branches/worktrees, commit hashes, key files, docs written, verification commands and results, blocked tests, deployment safety answer, and remaining manual steps.
   - Do not claim full acceptance when SQL, runtime, or real API checks are still blocked.

## Deployment Safety Checklist

Before saying the service can keep running during deployment, verify and document:

- New behavior is behind a feature flag or falls back to old behavior.
- Missing new tables do not break old authentication or old pages.
- SQL is not required before deploying code unless that is explicitly accepted.
- Turning off the flag disables the risky new path.
- Rollback can be done per repo or per commit.
- Manual SQL execution has backup and review requirements.
- Smoke tests cover both flag-off old behavior and flag-on new behavior.

Use precise language: say "旧路径应继续运行 when these conditions hold" instead of promising absolute uptime.
