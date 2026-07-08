---
name: rigorous-feature-delivery
description: Use as the end-to-end chain controller whenever the user asks to implement, fix, complete, plan, validate, or deliver a feature, bugfix, Linear issue, technical plan, or risky方案/方案落地; also use before saying an issue is done, after pushing a completed branch, or before asking/creating a PR. Applies one-issue-per-branch/PR scoping by default, functional branch names, pre-mortem for risky plans, rigorous-delivery review/red-team/full review gates, creating-pull-requests, and post-PR worktree cleanup.
---

# Rigorous Feature Delivery

Use this skill to execute large feature, refactor, or migration work end to end. Prefer it when the task spans multiple repositories, touches auth/data/schema behavior, requires deployment safety, or the user asks for a detailed plan and acceptance criteria.

## Required Skill Chain

Use this as the default chain for issue-driven feature/fix work:

1. **Plan/design:** Use `pre-mortem-design` before finalizing plans for payments, state machines, auth, durable data, concurrency, or external integrations.
2. **Scope binding:** Bind the work to one tracker issue by default. One worktree, branch, and PR should map to one issue's acceptance scope unless the user explicitly authorizes a combined branch.
3. **Implement/verify:** Use this skill plus `rigorous-delivery`; after code is written, `rigorous-delivery` review/red-team gates are mandatory before calling the issue complete.
4. **Ready-to-PR gate:** If the issue is considered complete and the branch has been pushed, ensure the `rigorous-delivery` risk-tiered PR gate has run once against the latest pushed commit before asking whether to create a PR. High-risk changes still require impact-radius full review (`4b-full`); low/medium-risk changes may use one comprehensive impact-radius reviewer plus focused tests. It must cover the current diff and high-coupling upstream/downstream flows, not unrelated repository areas. Do not run it twice unless code changed after the review.
5. **PR creation:** If the user wants a PR, use `creating-pull-requests`; do not hand-roll PR creation.
6. **Cleanup:** After the PR exists, clean up worktree directories created for the task so they do not accumulate.

## Issue Scope Binding

For issue-driven work, default to **one issue per worktree / branch / PR**:

- Use one tracker issue's acceptance criteria as the branch boundary.
- Branch names are still functional, not tracker IDs, but the branch scope must be traceable to exactly one issue.
- If the investigation reveals another issue, dependency, or adjacent risk, stop and classify it as a follow-up or separate branch. Do not implement it in the current branch unless the user explicitly approves combining scopes.
- If a batch issue contains sub-items, state which sub-items this branch covers. Do not imply the whole batch issue is complete unless every accepted sub-item is done and verified.
- PR text should describe the completed functional scope. Do not use closing keywords or issue IDs unless the project/user explicitly requires them.

## Workflow

1. Establish scope from local code before asking questions.
   - Inspect the relevant repos, routes, services, schema files, tests, and existing docs.
   - Identify the single tracker issue or accepted sub-item this branch will cover.
   - If a planned fix crosses into another issue's scope, split it into a separate branch or ask for explicit permission before mixing scopes.
   - Ask only when the answer cannot be discovered and a wrong assumption would be risky.
   - State assumptions explicitly in the tracking document.

2. Isolate the work.
   - Create a branch from the repo's mainline branch.
   - Branch names MUST be based on the functional change, not tracker IDs or issue numbers. Good: `fix/payment-webhook-renewal-guards`; bad: `fix/inf-857-858`.
   - Keep tracker IDs out of branch names unless the user explicitly overrides this rule.
   - Keep one branch scoped to one issue by default. If another issue is discovered, write it down as a follow-up instead of folding it into the current diff.
   - Use worktrees for multi-repo or high-risk changes.
   - Record original repo paths, worktree paths, branch names, and dirty baseline status.
   - Do not revert unrelated user changes.

3. Create and maintain a progress document.
   - Put the document in the primary repo unless the user asks otherwise.
   - Include objective, bound issue/sub-item, out-of-scope issue IDs or topics, constraints, repo paths, phases, files changed, tests, blocked tests, review notes, deployment plan, rollback plan, and acceptance criteria.
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
   - Follow `rigorous-delivery` Iron rule 7: state the risk tier, then run the matching independent review gate. High-risk changes require one independent normal reviewer subagent and one independent adversarial red-team subagent; low/medium-risk changes may use one comprehensive impact-radius reviewer unless the user asks for more.
   - Code is not "done" until the required risk-tiered review has passed, or all P0-P2 findings are fixed/re-verified with evidence.
   - `superpowers:requesting-code-review` may only supplement the normal review. It does not satisfy a required high-risk red-team pass and cannot replace `rigorous-delivery`.
   - If `rigorous-delivery` is unavailable but `superpowers:requesting-code-review` is available, use it for the normal review and still run a separate adversarial red-team review when the change is high-risk.
   - The review must check regressions, missing permission checks, deployment ordering, table-not-found behavior, token/user mismatch, rollback behavior, data-access/performance risk, and untested paths.
   - Fix findings or document residual risks with evidence.
   - If dedicated review/red-team skills or subagents are unavailable, record that limitation in the tracking document and final report; label the result as a local fallback, not as the required independent review.

9. Commit by functional slice.
   - For substantial single-issue work, create commits by module/functional slice. Target 2-5 commits.
   - Use these commit grouping rules, in order:
     1. DB/schema/migration compatibility changes: one `feat:` or `fix:` commit.
     2. Core backend service/business logic changes: one commit per cohesive service/module.
     3. API/WS/controller/route contract changes: one commit if they are separable from core service logic.
     4. Tests: commit with the module they verify when small; use one dedicated test commit when tests span multiple modules.
     5. Docs/handoff/progress notes: commit with the related module when narrow; use one final docs commit when docs summarize the whole feature.
     6. Review/red-team fixes: use a dedicated `fix:` commit when the fix is discovered after an earlier committed slice; otherwise include it in the relevant module commit before first commit.
   - Keep commit count within 2-5 for normal substantial work. More than 5 commits requires explicit user approval before pushing/PR.
   - A single commit is allowed only for tiny changes or naturally atomic changes. For non-trivial feature/fix/migration work, 1 commit requires explicit user approval before pushing/PR.
   - Do not create separate commits for formatting-only, import-only, generated-output-only, or one-line follow-up edits unless they belong to different functional modules. Fold them into the related module commit.
   - Before committing, write the intended commit plan in the progress document:
     - expected commit count
     - each commit's module/function scope
     - which files or file groups belong to each commit
   - Use Chinese commit subject/body and include `feat` or `fix` when required by the repo or user.
   - Mention verification or deployment-safety details in commit bodies when useful.

10. Push and PR readiness.
   - Push only after focused tests, full relevant tests, required risk-tiered review, and re-verification are complete.
   - If you believe the issue is complete after push, ensure the `rigorous-delivery` risk-tiered PR gate has run against the latest pushed commit and consolidate the findings before asking the user whether to create a PR.
   - Do not ask "要不要提 PR / 可以提 PR 了吗" until the required PR gate has no open P0/P1 and P2/P3 are either fixed or explicitly surfaced to the user for triage.
   - Treat this as the single PR-readiness gate. When `creating-pull-requests` runs later, it should verify this gate was already satisfied, not repeat it, unless commits changed after the review.

11. PR and cleanup.
   - If the user asks to create/open/submit a PR, switch to `creating-pull-requests` and follow its confirmation/body/base-branch rules.
   - After the PR is created, remove worktree directories created for this task using safe git worktree cleanup (`git worktree remove <path>` when possible), and verify `git worktree list` no longer shows stale task worktrees.
   - Never remove the user's original repo or unrelated worktrees.

12. Final report.
   - Include the single issue/sub-item covered, branches/worktrees, commit hashes, key files, docs written, verification commands and results, blocked tests, deployment safety answer, and remaining manual steps.
   - Include the actual commit count and list each commit hash with its module/function scope. If the branch has 1 commit or more than 5 commits, state the explicit user approval that allowed it.
   - List any adjacent issues found but intentionally not implemented.
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
