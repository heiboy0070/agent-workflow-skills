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
- Use risk-tiered per-round depth: low/medium risk may use a combined checklist; high risk gets separate current-agent normal and adversarial work plus the sequential `4b-full` matrix. Every risk tier still requires three consecutive P0/P1-clean rounds on the same final diff/commit.
- After a fix, run impacted tests first, then reset the clean-review streak to `0/3` and restart all three qualifying rounds on the new final diff. Any versioned code, test, configuration, migration, lockfile, or generated-file change resets the streak even when the review radius is unchanged.
- Keep user updates and final evidence compact. Include full raw output only for failures, short critical responses, disputed findings, or explicit user requests.

## Required Skill Chain

Use this as the default chain for feature/fix work:

1. **Plan/design:** Use `pre-mortem-design` before finalizing plans for payments, state machines, auth, durable data, concurrency, or external integrations.
2. **Tracker preflight:** First bind an existing tracker issue when the user provides one or a matching issue already exists. If no issue exists, continue with the user's accepted request as the scope boundary. Never create an issue only because this workflow is active; create one only when the user explicitly asks.
3. **Implement/verify:** Use this skill plus `rigorous-delivery`; follow its test policy, concentrated functional pass, grouped ordinary regression, three-round clean-review gate, and final evidence handoff. Its review/red-team gates remain mandatory before calling the accepted scope complete.
4. **Ready-to-PR gate:** Freeze each repository's final diff/commit and complete the `rigorous-delivery` gate as three sequential, consecutive review rounds with no new or open P0/P1 against that exact identity. Round N+1 starts only after Round N is recorded; parallel or duplicated reviews do not form a streak. High-risk changes require the current-agent impact-radius matrix (`4b-full`) within the applicable rounds; low/medium-risk changes use three distinct combined-impact rounds. A change after any round resets that repository to `0/3`; if it changes a shared contract or coupled behavior, reset every affected repository's streak.
5. **PR creation (no handoff pause):** Reaching `3/3` completes the PR-readiness gate. When the user asks to create/submit a PR, that instruction is the authorization — invoke `creating-pull-requests` directly, generate the body from its template, and create the PR; show the link plus full body in chat after (or in the same turn) for review. Do NOT insert a separate "output PR material and wait for confirmation" round-trip. When the user has NOT asked for a PR, do not force PR material into the final report — name the readiness state and let the user decide.
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
   - Before creating a follow-up migration, determine whether the existing feature migration has reached production or another shared immutable environment.
   - If the feature migration has not reached production, keep one complete schema entry: add every required table, column, index, backfill, and compatibility guard to that original migration. If a development or personal test database may have executed an earlier revision, append database-version-compatible idempotent ALTER/backfill statements to the end of the same file so both a clean production database and the partially migrated test database can execute that one file safely.
   - Create a new follow-up migration only after the original migration has reached production/shared immutable state or repository policy forbids editing applied migrations. Do not scatter required DDL across chat, PR text, deployment documents, or multiple SQL files merely because a personal test database ran an earlier draft.
   - Verify both paths before handoff: clean database executes the complete migration; earlier-revision database executes the updated file without duplicate-column/table failures. Compare every table/column/index referenced by the code against the migration artifact.
   - Document which tests remain blocked until SQL is manually reviewed and executed.

5. Implement in reviewable slices.
   - Treat slices as logical scope and commit boundaries, not mandatory stop points after every ordinary endpoint.
   - Complete related ordinary CRUD/query/mapping interfaces in one concentrated functional pass, then add grouped regression/contract coverage.
   - Use test-first implementation only for the critical behaviors classified by `rigorous-delivery`, including state machines, concurrency/idempotency, auth, durable mutation, external callbacks/retries, security-sensitive validation, client-blocking contracts, and reproduced defects.
   - Follow existing code patterns and keep unrelated refactors out.
   - Add feature flags for risky behavior when old behavior must continue during deployment.
   - Prefer backward-compatible schema and response changes.
   - For auth/token work, document token ownership, expiry, revocation, and fallback behavior.
   - Enforce the mandatory user-facing feedback contract below at the API/client boundary; do not defer copy safety to individual components.

### Mandatory user-facing feedback contract

- Treat all non-client-owned feedback and diagnostic text as untrusted internal data, regardless of success/failure status. This includes text returned or thrown by backends, upstream services, proxies, third-party SDKs, browser/native bridges, and realtime channels.
- No user-facing surface may render, interpolate, forward, or use as a fallback any such text, including nested `message`, `error`, `detail`, `reason`, `title`, `description`, `cause`, `stack`, `statusText`, raw response bodies, exception text, API/SDK-originated `Error.message`, or `err.Error()`. These names are examples, not an allowlist: any diagnostic string not fully owned by the client is prohibited.
- “User-facing surface” includes pages, field validation, error/empty states, toasts, snackbars, banners, modals, dialogs, drawers, tooltips, notifications, accessibility announcements, redirects/query text, and generated/downloadable user output. Existing passthrough conventions, backend localization or product approval, time pressure, preserving “specific details,” and avoiding a mapping layer are not exceptions.
- Enforce the contract at every transport and rendering boundary: HTTP/GraphQL/RPC, SSR/RSC/server actions/loaders, BFF/reverse proxies, WebSocket/SSE, third-party SDKs, and browser/native WebView bridges. Normalize feedback into a stable code, status/business state, safe structured metadata, and request/trace ID. Map allowlisted known cases to product-owned, contextual copy or a purpose-built recovery UI such as retry, re-authentication, field correction, or support guidance.
- For an unknown, missing, malformed, or newly introduced code, show a client-owned context-specific fallback. Never implement `backendMessage ?? fallback`, pass a raw exception into a UI prop/state/store, or reveal raw text because a mapping is absent.
- Raw diagnostic text may exist only in access-controlled observability or development logs, separate from UI state. Redact secrets, tokens, credentials, and personal data; prefer the stable code and request/trace ID. A log, audit event, session replay, debug console, or realtime log stream that can be read, subscribed to, exported, or displayed by a client is user-facing and must remove raw diagnostics before applying the same mapping contract. Domain content intentionally returned for display is not a substitute channel for feedback or diagnostic messages.

6. Verify with real commands.
   - Start the staged smoke/review/full gate after the accepted functional pass is complete; do not interrupt every ordinary endpoint with a full verification cycle.
   - Before starting local services, state each port and which backend it represents.
   - Keep frontend base URL variables mapped to their real backend roles; do not point unrelated PHP/V2/Node variables to the same address unless explicitly doing a labeled mock-only test.
   - Run focused tests for new behavior.
   - Run build/lint/typecheck for touched services where available.
   - For any frontend/UI change, derive a complete affected-UI inventory from the diff, route tree, user flow, and responsive variants before browser verification. Give every affected route or materially different UI state its own matrix row; mark non-visual frontend infrastructure changes as “no independent UI” with supporting evidence instead of silently omitting them.
   - Treat every materially different user-facing feedback state, including success, failure, and realtime events, as an affected-UI row. Inventory every applicable source among HTTP, SSR/BFF, third-party SDK, WebSocket/SSE, and WebView/native bridges. For every touched feedback path and applicable source, inject hostile or sensitive upstream text and add tests proving: known codes produce the exact product-owned copy or recovery UI; unknown/missing/malformed codes produce the contextual fallback; and raw upstream text is absent from the rendered DOM, accessibility tree, toast/notification output, URL, native notification/bridge output, and downloadable output.
   - Verify every visual row through real interaction in a headed browser. Cover desktop and mobile separately whenever the layout, navigation, copy, target, or control behavior differs. Sampling one page, one state, one viewport, or relying only on unit/snapshot tests does not satisfy UI acceptance.
   - Capture at least one screenshot for every verified visual row. Record the route/state, viewport, observed result, and screenshot path in the evidence ledger. A visual row without screenshot evidence remains unverified and the UI scope MUST NOT be reported complete.
   - If full suites fail on baseline, document the baseline failures and run scoped tests.
   - If runtime, database, or table prerequisites are missing, record exact unblock steps and acceptance criteria in chat or a temporary file outside the repository.
   - Stop any local dev server, mock API, browser session, or background process started for the test when the test finishes, fails, or is interrupted.

7. Deliver the handoff without repository clutter.
   - Provide the final handoff in chat after implementation and verification stabilize, using the accumulated evidence.
   - Create an API/integration or deployment document in the repository only when the user requested that document or the repository requires it as a product artifact.
   - For deployment-risk work, include rollout order, smoke tests, rollback switch, and what is not guaranteed in the final handoff even when no file is created.

8. Review and red-team before completion.
   - Invoke `rigorous-delivery` for this gate and follow its current-agent review checklists.
   - State the risk tier. It controls each round's depth, not the exit count: every tier and every repository requires three sequential P0/P1-clean rounds against its same final identity. High-risk rounds include separate normal/adversarial work; low/medium-risk rounds may use distinct combined-impact checklists.
   - Code is not "done" until the exact final diff/commit has a `3/3` record and every P0/P1 is fixed/re-verified with evidence. Record and surface P2/P3; they do not block unless the user makes them blocking or they affect safety/security/data integrity.
   - Do not invoke another review workflow that automatically delegates. The current-agent normal and adversarial passes are the canonical gate.
   - The review must check regressions, missing permission checks, deployment ordering, table-not-found behavior, token/user mismatch, rollback behavior, data-access/performance risk, and untested paths.
   - Trace all touched feedback paths—including success, failure, realtime, SSR/BFF, SDK, and bridge paths—from transport to presentation. Search for diagnostic strings, raw bodies, `.message`, `cause`, `stack`, `statusText`, and `err.Error()` entering UI state, props, stores, templates, toasts, notifications, accessibility text, URLs, native bridges, or generated output. Any user-facing passthrough is a blocking P1; exposure of secrets, credentials, tokens, or personal data is P0. A missing source inventory, hostile-text injection test, or required evidence is also an unverified P1. Do not close or ship the accepted scope until it is removed and re-verified.
   - 在支付/退款/状态机/重试等关键业务路径的提案和落地中，要求预先定义最小可用业务日志点：关键入口参数摘要、分支判断/状态迁移、外部网关调用前后、幂等键/乐观锁冲突处理、重试/补偿动作。日志应为结构化、可追溯（如 requestID/traceID/businessID），只打印关键节点，避免热路径高频噪声日志。
   - Fix findings or document residual risks with evidence.
   - Record each round's number, commit SHA/diff identity, independent angle, selected radius, findings, dispositions, and evidence in the shared ledger. Any versioned change resets the record to `0/3`; PR preparation may reuse only a complete `3/3` record for the unchanged final identity.

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
   - Before pushing, rerun `scripts/validate-branch-name.sh "$(git branch --show-current)"`. A rejected branch MUST be renamed and rechecked before any push or PR creation.
   - Run `scripts/validate-workflow-artifacts.sh <base> [head]`. Remove every rejected workflow Markdown file from the commit/PR unless the user or repository explicitly required that exact versioned document; record that exception in the post-create body shown in chat.
   - Push only the frozen commit that passed focused/full tests and the three-round clean-review gate. After push, confirm the remote head SHA exactly matches the reviewed SHA; a push containing a different commit resets the gate.
   - Do not ask "要不要提 PR / 可以提 PR 了吗" before the exact final identity has `3/3`, no open P0/P1, and P2/P3 are explicitly surfaced for triage.
   - Treat the `3/3` ledger as the single PR-readiness record. When `creating-pull-requests` runs later, it verifies this record instead of repeating it, unless any commit or diff changed after review.

11. PR and cleanup.
   - If the user asks to create/open/submit a PR, invoke `creating-pull-requests` directly (base 分支由用户指令指定；模板 body 生成后直接创建，不设事前 handoff 停顿); do not hand-roll creation.
   - When no PR was requested, the final report only states the readiness identity (branch, commit SHA, `3/3` gate status) — it does not inline a full PR payload.
   - After the PR is created, remove worktree directories created for this task using safe git worktree cleanup (`git worktree remove <path>` when possible), and verify `git worktree list` no longer shows stale task worktrees.
   - Never remove the user's original repo or unrelated worktrees.

12. Final report.
   - Include the bound issue when one exists; otherwise name the accepted request/sub-item scope. Also include branches/worktrees, commit hashes, key files, explicitly requested product docs, verification commands and results, blocked tests, deployment safety answer, and remaining manual steps.
   - Include the actual commit count and list each commit hash with its module/function scope. If the branch has 1 commit or more than 5 commits, state the explicit user approval that allowed it.
   - For frontend/UI scope, include the affected-UI verification matrix with one row per route/state and responsive variant, plus a visible preview or clickable local link for every required screenshot. Explicitly list any row that could not be exercised; do not collapse multiple unverified pages into a generic “browser test passed” statement.
   - For touched feedback/error paths, include the stable-code-to-copy/UI mapping, unknown-code fallback, automated non-disclosure test result, and screenshot evidence for each visual error state. Explicitly state whether any backend feedback/diagnostic text can still reach a user-facing surface; if that cannot be proven false, do not report the scope complete.
   - Include a three-row review ledger summary per repository: round, exact commit/diff identity, independent angle, P0 count, P1 count, and evidence reference. Anything below `3/3`, any mixed commit identities, or any open P0/P1 means the task remains in progress.
   - End with the complete PR-ready handoff for every branch: `base`, `head`, title, and body containing summary, verification, screenshots/UI matrix when applicable, rollout/deployment notes, and disclosed P2/P3. Do not wait for the user to ask for this payload.
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
