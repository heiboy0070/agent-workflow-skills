---
name: rigorous-feature-delivery
description: Use when implementing, fixing, completing, planning, validating, or delivering a feature, bugfix, Linear issue, technical plan, or risky方案/方案落地; also use before declaring completion or preparing a PR.
---

# Rigorous Feature Delivery

Use this skill to execute large feature, refactor, or migration work end to end. Prefer it when the task spans multiple repositories, touches auth/data/schema behavior, requires deployment safety, or the user asks for a detailed plan and acceptance criteria.

## Token-Efficient Execution Policy

- The current agent owns reconnaissance, planning, implementation, normal review, red-team, verification, and PR preparation end to end.
- Do not invoke Task/Agent/subagent tools unless the user explicitly requests delegation in the current task. Multi-repo work alone is not permission to delegate.
- Read/search independent files in parallel through ordinary tools when available, but avoid duplicating context in multiple agents.
- After scope and critical-risk design are clear, finish one concentrated functional implementation pass before ordinary regression, review, and final user handoff. Keep only critical-path test-first loops inside that pass.
- Create one evidence ledger per task: command, commit/build identity, concrete data, observed result, and raw-output reference. Reuse it across review, acceptance, and PR preparation while the relevant diff is unchanged.
- Use risk-tiered depth: low/medium risk gets a combined review checklist; high risk gets separate current-agent normal and adversarial passes plus the sequential `4b-full` matrix.
- After a narrow fix, rerun only impacted tests and review rows. Rerun the full gate only when the review radius changes.
- Keep user updates and final evidence compact. Include full raw output only for failures, short critical responses, disputed findings, or explicit user requests.

## Required Skill Chain

Use this as the default chain for feature/fix work:

1. **Plan/design:** Use `pre-mortem-design` before finalizing plans for payments, state machines, auth, durable data, concurrency, or external integrations.
2. **Tracker preflight:** First bind an existing tracker issue when the user provides one or a matching issue already exists. If no issue exists, continue with the user's accepted request as the scope boundary. Never create an issue only because this workflow is active; create one only when the user explicitly asks.
3. **Implement/verify:** Use this skill plus `rigorous-delivery`; follow its risk-tiered test policy, concentrated functional pass, grouped ordinary regression, and final evidence handoff. Its review/red-team gates remain mandatory before calling the accepted scope complete.
4. **Ready-to-PR gate:** If the accepted scope is considered complete and the branch has been pushed, ensure the `rigorous-delivery` risk-tiered PR gate has run once against the latest pushed commit before asking whether to create a PR. High-risk changes require the current-agent impact-radius matrix (`4b-full`); low/medium-risk changes use one combined pass plus focused tests. Reuse the gate while the reviewed diff is unchanged.
5. **PR-ready handoff:** 到可提 PR 阶段，先向用户输出：`base` 分支、`head` 分支、PR 标题、PR 正文。必须得到用户确认后再进入 `creating-pull-requests` 流程。
6. **PR creation:** If the user wants a PR, use `creating-pull-requests`; do not hand-roll PR creation.
6. **Cleanup:** After the PR exists, clean up worktree directories created for the task so they do not accumulate.

## Issue Scope Binding

Run tracker binding as a preflight, not as an issue-creation requirement:

- If the user supplies an issue, bind the work to it before implementation.
- If an accessible tracker contains a clear matching issue, bind that existing issue and record the match.
- If no matching issue exists, do not create one automatically and do not block implementation. Treat the user's accepted request or explicitly accepted sub-item set as the branch boundary.
- Treat exploratory ideas, temporary experiments, and provisional investigations as valid untracked work unless the user explicitly promotes them into an issue.
- Create a new tracker issue only when the user explicitly requests issue creation. Do not infer permission from “use the workflow,” “start implementation,” or the presence of a Linear project.

When an existing issue is bound, default to **one issue per worktree / branch / PR**:

- Use one tracker issue's acceptance criteria as the branch boundary.
- Branch names are still functional, not tracker IDs, but the branch scope must be traceable to exactly one issue.
- If the investigation reveals another issue, dependency, or adjacent risk, stop and classify it as a follow-up or separate branch. Do not implement it in the current branch unless the user explicitly approves combining scopes.
- If a batch issue contains sub-items, state which sub-items this branch covers. Do not imply the whole batch issue is complete unless every accepted sub-item is done and verified.
- PR text should describe the completed functional scope. Do not use closing keywords or issue IDs unless the project/user explicitly requires them.

## Workflow

1. Establish scope from local code before asking questions.
   - Inspect the relevant repos, routes, services, schema files, tests, and existing docs.
   - Check for a user-provided or clearly matching existing tracker issue. Bind it when found; otherwise record the user's accepted request or accepted sub-item set as the branch scope without creating a new issue.
   - If a planned fix crosses into another issue's scope, split it into a separate branch or ask for explicit permission before mixing scopes.
   - Ask only when the answer cannot be discovered and a wrong assumption would be risky.
   - State assumptions in the working context or temporary evidence ledger.

2. Isolate the work.
   - Create a branch from the repo's mainline branch.
   - Branch names MUST use `<group>/<english-kebab-case-description>`. Use the repository's documented group when present; otherwise choose a functional group such as `feature`, `feat`, `fix`, `hotfix`, `refactor`, `chore`, `docs`, or `test`.
   - The entire branch name MUST be ASCII English: lowercase letters and digits separated by single hyphens. Do not use Chinese, spaces, underscores, usernames, owner prefixes, or generated issue-title slugs.
   - Branch names MUST describe the functional change and MUST NOT contain tracker IDs, issue numbers, or issue-key fragments. Good: `fix/payment-webhook-renewal-guards`; bad: `ruanlianjie/inf-857-修复支付`, `fix/inf-857-858`, or `feature/PROJ-123-payment-fix`.
   - Before creating a branch or worktree, run `scripts/validate-branch-name.sh <branch>` from this skill directory. If the validator rejects the name, choose a new name; do not create first and rename later.
   - Keep one branch scoped to one bound issue or one accepted request by default. If another issue is discovered, write it down as a follow-up instead of folding it into the current diff.
   - Use worktrees for multi-repo or high-risk changes.
   - Record original repo paths, worktree paths, branch names, and dirty baseline status.
   - Do not revert unrelated user changes.

3. Keep workflow artifacts out of product history.
   - Keep scope, plans, decisions, commands, raw evidence, blockers, commit plans, and handoff notes in the working context, tool log, or a temporary path outside the repository.
   - Agent-generated plan/spec/design/progress/tracker/evidence/handoff Markdown is temporary workflow material. Even if created, it MUST NOT be staged, committed, or included in a PR.
   - This rule overrides subordinate skills that require saving or committing `docs/superpowers/plans/*.md`, `docs/superpowers/specs/*.md`, or similar workflow documents. Store such content outside the repository or provide it in chat instead.
   - A Markdown file may enter git only when the user explicitly requests that exact document as a deliverable or the repository explicitly requires it as a versioned product artifact. API/integration documentation requested as part of the product is not a workflow artifact.

4. Treat database changes as reviewable artifacts.
   - Never execute production or project SQL unless the user explicitly asks and approves.
   - Add migration or SQL files with clear comments and execution notes.
   - Document which tests remain blocked until SQL is manually reviewed and executed.

5. Implement in reviewable slices.
   - Treat slices as logical scope and commit boundaries, not mandatory stop points after every ordinary endpoint.
   - Complete related ordinary CRUD/query/mapping interfaces in one concentrated functional pass, then add grouped regression/contract coverage.
   - Use test-first implementation only for the critical behaviors classified by `rigorous-delivery`, including state machines, concurrency/idempotency, auth, durable mutation, external callbacks/retries, security-sensitive validation, client-blocking contracts, and reproduced defects.
   - Follow existing code patterns and keep unrelated refactors out.
   - Add feature flags for risky behavior when old behavior must continue during deployment.
   - Prefer backward-compatible schema and response changes.
   - For auth/token work, document token ownership, expiry, revocation, and fallback behavior.

6. Verify with real commands.
   - Start the staged smoke/review/full gate after the accepted functional pass is complete; do not interrupt every ordinary endpoint with a full verification cycle.
   - Before starting local services, state each port and which backend it represents.
   - Keep frontend base URL variables mapped to their real backend roles; do not point unrelated PHP/V2/Node variables to the same address unless explicitly doing a labeled mock-only test.
   - Run focused tests for new behavior.
   - Run build/lint/typecheck for touched services where available.
   - If full suites fail on baseline, document the baseline failures and run scoped tests.
   - If runtime, database, or table prerequisites are missing, record exact unblock steps and acceptance criteria in chat or a temporary file outside the repository.
   - Stop any local dev server, mock API, browser session, or background process started for the test when the test finishes, fails, or is interrupted.

7. Deliver the handoff without repository clutter.
   - Provide the final handoff in chat after implementation and verification stabilize, using the accumulated evidence.
   - Create an API/integration or deployment document in the repository only when the user requested that document or the repository requires it as a product artifact.
   - For deployment-risk work, include rollout order, smoke tests, rollback switch, and what is not guaranteed in the final handoff even when no file is created.

8. Review and red-team before completion.
   - Invoke `rigorous-delivery` for this gate and follow its current-agent review checklists.
   - State the risk tier. High-risk changes require separate normal and adversarial passes by the current agent; low/medium-risk changes use one combined impact pass unless the user asks for more.
   - Code is not "done" until the required risk-tiered review has passed, or all P0-P2 findings are fixed/re-verified with evidence.
   - Do not invoke another review workflow that automatically delegates. The current-agent normal and adversarial passes are the canonical gate.
   - The review must check regressions, missing permission checks, deployment ordering, table-not-found behavior, token/user mismatch, rollback behavior, data-access/performance risk, and untested paths.
   - 在支付/退款/状态机/重试等关键业务路径的提案和落地中，要求预先定义最小可用业务日志点：关键入口参数摘要、分支判断/状态迁移、外部网关调用前后、幂等键/乐观锁冲突处理、重试/补偿动作。日志应为结构化、可追溯（如 requestID/traceID/businessID），只打印关键节点，避免热路径高频噪声日志。
   - Fix findings or document residual risks with evidence.
   - Record the selected review radius, findings, dispositions, and evidence in the shared ledger so PR preparation does not repeat the review.

9. Commit by functional slice.
   - For substantial work, create commits by module/functional slice. Target 2-5 commits whether the scope comes from a bound issue or an accepted untracked request.
   - Use these commit grouping rules, in order:
     1. DB/schema/migration compatibility changes: one `feat:` or `fix:` commit.
     2. Core backend service/business logic changes: one commit per cohesive service/module.
     3. API/WS/controller/route contract changes: one commit if they are separable from core service logic.
     4. Tests: commit with the module they verify when small; use one dedicated test commit when tests span multiple modules.
     5. Explicit product documentation: when the user or repository requires a versioned API/integration/product document, commit it with the related implementation or review-fix slice; never use workflow notes as a commit-count filler.
     6. Review/red-team fixes: use a dedicated `fix:` commit when the fix is discovered after an earlier committed slice; otherwise include it in the relevant module commit before first commit.
   - Keep commit count within 2-5 for normal substantial work. More than 5 commits requires explicit user approval before pushing/PR.
   - A single commit is allowed only for tiny changes or naturally atomic changes. For non-trivial feature/fix/migration work, 1 commit requires explicit user approval before pushing/PR.
   - Do not create separate commits for formatting-only, import-only, generated-output-only, or one-line follow-up edits unless they belong to different functional modules. Fold them into the related module commit.
   - The workflow-artifact exclusion overrides subordinate skill instructions. If another skill says to save or commit a design/spec/plan, keep it outside the repository and do not fold it into any functional commit.
   - Before committing, write the intended commit plan in the working context or temporary ledger:
     - expected commit count
     - each commit's module/function scope
     - which files or file groups belong to each commit
   - Use Chinese commit subject/body and include `feat` or `fix` when required by the repo or user.
   - Mention verification or deployment-safety details in commit bodies when useful.

10. Push and PR readiness.
   - Before pushing, rerun `scripts/validate-branch-name.sh "$(git branch --show-current)"`. A rejected branch MUST be renamed and rechecked before any push or PR handoff.
   - Run `scripts/validate-workflow-artifacts.sh <base> [head]`. Remove every rejected workflow Markdown file from the commit/PR unless the user or repository explicitly required that exact versioned document; record that exception in the PR handoff.
   - Push only after focused tests, full relevant tests, required risk-tiered review, and re-verification are complete.
   - If you believe the accepted scope is complete after push, ensure the `rigorous-delivery` risk-tiered PR gate has run against the latest pushed commit and consolidate the findings before asking the user whether to create a PR.
   - Do not ask "要不要提 PR / 可以提 PR 了吗" until the required PR gate has no open P0/P1 and P2/P3 are either fixed or explicitly surfaced to the user for triage.
   - Treat this as the single PR-readiness gate. When `creating-pull-requests` runs later, it should verify this gate was already satisfied, not repeat it, unless commits changed after the review.

11. PR and cleanup.
   - If the user asks to create/open/submit a PR, first output PR-ready handoff（`base` + `head` + title + body）并等待用户确认，然后切到 `creating-pull-requests`，执行其后续步骤。
   - After the PR is created, remove worktree directories created for this task using safe git worktree cleanup (`git worktree remove <path>` when possible), and verify `git worktree list` no longer shows stale task worktrees.
   - Never remove the user's original repo or unrelated worktrees.

12. Final report.
   - Include the bound issue when one exists; otherwise name the accepted request/sub-item scope. Also include branches/worktrees, commit hashes, key files, explicitly requested product docs, verification commands and results, blocked tests, deployment safety answer, and remaining manual steps.
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
