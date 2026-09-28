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

1. **Design first (设计先行，强制门):** No product code before a frozen design exists. Use `pre-mortem-design` for payments, state machines, auth, durable data, concurrency, or external integrations. The design MUST contain a **closed-loop definition** (see "设计先行与闭环设计" below) — the end-to-end path plus, for every segment, the observation that proves it actually happened. When the scope was reached by exploration or user pushback, or the work will span context compaction/sessions, freeze the objective, invariants, key details, closed-loop definition, and acceptance criteria in a plan document first (Workflow step 2). A tiny change still needs a design, but three lines in the ledger are enough — what is forbidden is implementing with no design and "closing the loop later".
2. **Tracker preflight:** First bind an existing tracker issue when the user provides one or a matching issue already exists. If no issue exists, continue with the user's accepted request as the scope boundary. Never create an issue only because this workflow is active; create one only when the user explicitly asks.
3. **Implement/verify:** Use this skill plus `rigorous-delivery`; follow its test policy, concentrated functional pass, grouped ordinary regression, three-round clean-review gate, and final evidence handoff. Its review/red-team gates remain mandatory before calling the accepted scope complete.
4. **Ready-to-PR gate:** Freeze each repository's final diff/commit and complete the `rigorous-delivery` gate as three sequential, consecutive review rounds with no new or open P0/P1 against that exact identity. Round N+1 starts only after Round N is recorded; parallel or duplicated reviews do not form a streak. High-risk changes require the current-agent impact-radius matrix (`4b-full`) within the applicable rounds; low/medium-risk changes use three distinct combined-impact rounds. A change after any round resets that repository to `0/3`; if it changes a shared contract or coupled behavior, reset every affected repository's streak.
5. **PR creation (no handoff pause):** Reaching `3/3` completes the PR-readiness gate. When the user asks to create/submit a PR, that instruction is the authorization — invoke `creating-pull-requests` directly, generate the body from its template, and create the PR; show the link plus full body in chat after (or in the same turn) for review. Do NOT insert a separate "output PR material and wait for confirmation" round-trip. When the user has NOT asked for a PR, do not force PR material into the final report — name the readiness state and let the user decide.
6. **Cleanup:** After the PR exists, clean up worktree directories created for the task so they do not accumulate.

## 设计先行与闭环设计（强制，用户明确要求）

> 工作流从**设计**开始：设计冻结之后才允许写实现。设计阶段的第一产出不是接口清单，而是**闭环定义**。

**闭环（closed loop）= 一条能力从「用户意图」到「可观测结果」的完整链路，且链路每一段都有可执行的验证手段。**
「接口返回 200」不是闭环；**客户端真的拿到了、消费了、并且我们能用证据证明它拿到了**才是闭环。

### 设计文档必须写清的四件套

1. **链路图**：用真实端点 / 函数名 / 表名 / 存储对象写出全程：
   入口 → 鉴权 → 取数 → 变换 → 出口（谁消费）→ 终止（过期 / 撤销 / 清理）。
2. **每段的观测点**：这一段凭什么证明它真的发生了——HTTP 状态码、数据库行、指标计数器、响应字段、客户端可见状态。
   写不出观测点的段，就是设计缺陷（无法验收），必须在设计阶段改掉，而不是上线后靠日志猜。
3. **断点清单**：每一段可能**静默失败**的形态，以及它对外会伪装成什么。至少要覆盖：
   上游在业务逻辑之前拒绝却回 200 信封 / 数据存在但当前不可读（归档、冻结、软删）/ 地址合法但对象不在我们桶里 /
   前置校验写死导致正常数据被挡 / 权限或目录策略比真实数据布局更窄 /
   **配置面静默降级**：取值被夹到上界、回落到默认值、只对部分实例生效，以及"开关是开着但能力并没在运行"（config ≠ execution）。
   最后这一类都不报错，只会把"我改过了"变成假事实 ⇒ 凡有 clamp/回落都必须留痕（原值与生效值），并在交付里给出核对生效值的方法。
4. **验收即闭环检查**：一条端到端断言串起全程，并且**每个可能断的段都有反例断言**
   （伪造凭证 → 拒绝、无凭证 → 拒绝、不可读状态 → 专用状态码、字段缺失 → 明确降级），
   反例断言必须能在旧代码上失败（变异检验），否则它证明不了任何东西。

### 反例（2026-09-22 金运录音 MCP 连接器实战，四个断点全都表现为"成功"）

| 断点 | 表面的样子 | 真因 / 正解 |
|---|---|---|
| 媒体取流拿地址主机做准入 | 接口 200、链路"通" | 自定义域名/CDN/路径式地址全被拒 → **主机不参与映射，只按路径取对象** |
| 录音目录前缀写死 `uploads/audio/` | 同上 | 测试/历史数据布局不同 → **目录策略可配置，默认不变** |
| 对象处于冷归档 | 代理 503「服务暂时不可用」 | `403 InvalidObjectState` 是**数据状态不是故障** → 409 + 专用错误码 + 自动解冻 |
| 授权页发码漏带服务间令牌 | 页面「验证码已发送」 | 上游中间件回 `1008`，**一条短信都没发出** → 带令牌 + 只对白名单码回「已发送」 |

结论：**闭环必须在设计阶段定义，并在验收阶段用证据逐段回填**；否则每一个断点都会伪装成"已经能用"。

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

2. Freeze the design before implementing (设计门：设计没冻结，不写实现).
   - **Step order is not negotiable:** establish scope (step 1) → design + freeze (this step) → implement (step 6). If the user asks for implementation while the design is missing or unconfirmed, say so and produce the design first; do not "write a bit then design".
   - Write one **frozen plan document** before touching product code when the scope was reached through exploration, user pushback, or several rounds of Q&A, or when the task will outlive one context window, span sessions, or produce many commits. For a slice that is already fully specified, the design may be short — but it must still exist (sequence, closed-loop definition, acceptance checks) and be recorded in the working context/ledger.
   - The document MUST pin down: the final objective and its observable results; the invariant(s) that must never be violated; every confirmed decision **and the alternative it rejected**; the key details and edge cases a later session would otherwise get wrong (exact table/column/key names, resolution and precedence rules, default values, boundary cases); the data-model and API/UI contract; what is explicitly out of scope; the verification plan; and **acceptance criteria written as individually verifiable checks** (a command, an endpoint call, an observed DB state, or a UI action).
   - The document MUST also contain the **closed-loop definition** (see "设计先行与闭环设计"): the end-to-end path by real endpoint/function/table names, the observation that proves each segment, the silent-failure list, and the counter-example assertions — including the segment that a previous implementation silently dropped. A design that cannot say how each segment will be observed is not ready to implement.
   - Record corrected misconceptions explicitly, with the reason the rejected version was wrong. That one line is what stops a later session from re-introducing a design the user already refused.
   - **改既有取值前先考古它的历史意图（通用门禁）**：改动任何既有常量、阈值、默认值或开关前，对**同一语义的每个消费点**分别回溯引入提交与理由（`git log -S "<旧值>" -- <file>`），连同注释一起读。若有人**刻意**为此设过值并写明理由：① 该理由必须作为"被否决的替代方案"进入本设计；② 若本次改动会取消它，必须交用户拍板，不得自行定性为"清理地雷"。同一语义若在多层各有一份上界，逐层验证都接受目标值 —— **两层引入日期不一致 = 存在"只改了一半"的窗口**：那种"配置面支持、运行层拒绝"的修复从未生效过，且不会有人发现。
   - Keep the document untracked and out of product history (see step 4). Prefer a repository-local untracked path only when that repository's own convention designates one for plans; otherwise store it outside the repository.
   - Frozen means frozen: implement against it item by item. Amendments require an appended change-log entry stating what changed and why; never silently rewrite a frozen clause.
   - On resume after compaction, a fork, or a new session, re-read the frozen document before writing code, and re-verify its premises against live code and data — a frozen plan is never evidence that the code still matches it.
   - The document is a scope fence, not proof. It never substitutes for tests, red-to-green evidence, or acceptance verification.

3. Isolate the work.
   - Create a branch from the repo's mainline branch.
   - Branch names MUST use `<group>/<english-kebab-case-description>`. Use the repository's documented group when present; otherwise choose a functional group such as `feature`, `feat`, `fix`, `hotfix`, `refactor`, `chore`, `docs`, or `test`.
   - The entire branch name MUST be ASCII English: lowercase letters and digits separated by single hyphens. Do not use Chinese, spaces, underscores, usernames, owner prefixes, or generated issue-title slugs.
   - Branch names MUST describe the functional change and MUST NOT contain tracker IDs, issue numbers, or issue-key fragments. Good: `fix/payment-webhook-renewal-guards`; bad: `ruanlianjie/inf-857-修复支付`, `fix/inf-857-858`, or `feature/PROJ-123-payment-fix`.
   - Before creating a branch or worktree, run `scripts/validate-branch-name.sh <branch>` from this skill directory. If the validator rejects the name, choose a new name; do not create first and rename later.
   - Keep one branch scoped to one bound issue or one accepted request by default. If another issue is discovered, write it down as a follow-up instead of folding it into the current diff.
   - Use worktrees for multi-repo or high-risk changes.
   - Record original repo paths, worktree paths, branch names, and dirty baseline status.
   - Do not revert unrelated user changes.

4. Keep workflow artifacts out of product history.
   - Keep scope, plans, decisions, commands, raw evidence, blockers, commit plans, and handoff notes in the working context, tool log, or a temporary path outside the repository.
   - Agent-generated plan/spec/design/progress/tracker/evidence/handoff Markdown is temporary workflow material. Even if created, it MUST NOT be staged, committed, or included in a PR.
   - This rule overrides subordinate skills that require saving or committing `docs/superpowers/plans/*.md`, `docs/superpowers/specs/*.md`, or similar workflow documents. Store such content outside the repository or provide it in chat instead — except when the repository's own convention designates a specific untracked local path for plans (for example a `CLAUDE.md` rule that plan files live under `docs/superpowers/plans/` and are never committed), in which case that path is allowed and the file MUST stay untracked.
   - A Markdown file may enter git only when the user explicitly requests that exact document as a deliverable or the repository explicitly requires it as a versioned product artifact. API/integration documentation requested as part of the product is not a workflow artifact.

5. Treat database changes as reviewable artifacts.
   - Never execute production or project SQL unless the user explicitly asks and approves.
   - Add migration or SQL files with clear comments and execution notes.
   - For every new persistent table, complete the `pre-mortem-design` **新表影响矩阵**; a missing field or an unjustified runtime table blocks implementation.
   - Before changing an online database path, record the affected endpoint/worker's before-and-after ordered SQL list, serial SQL round-trip count, transaction boundaries, and cross-region RTT additions. Migration state, `READY`, and one-time validation must stay in deployment/migration/CI unless a documented runtime-safety reason requires the hot-path access.
   - Any cross-region performance claim requires query logs or a reproducible measurement. Record the p50/p95/p99 measurement plan and status (measured or `待测试环境测量`), `EXPLAIN`/index evidence, concurrency assumptions, and connection-pool upper bound. Local development does not require real production metrics, but pending evidence cannot be reported as a performance improvement.
   - **One module = one cumulative schema file（用户策略，覆盖原两分支规则）**：同属一个模块的全部表/列/索引必须收敛在同一个模块 schema 文件里（如 `create_billing_reservations.sql` 盖住整个计费/支付模块），**无论原迁移是否已上生产**。对该文件的后续变更一律：① 把新列/索引同步进对应 `CREATE TABLE IF NOT EXISTS` 定义（全新库路径）；② 在文件末尾追加 information_schema 守卫的幂等 ALTER/BACKFILL 块（存量库路径）。禁止为同模块 schema 变更新建独立 alter 文件，也禁止把模块 DDL 散落到多个文件、聊天记录、PR 正文或部署文档里。
   - 例外：仓库已有明确的多文件迁移版本化机制（如 golang-migrate 版本表）且策略禁止改已应用版本文件时，遵循仓库机制新建版本化迁移，但新文件仍须按模块命名归组。
   - Verify both paths before handoff: clean database executes the complete file (CREATE includes new columns, guards no-op); earlier-revision database re-executes the same file without duplicate-column/table failures (guards skip). Compare every table/column/index referenced by the code against the migration artifact, and keep the guarded ALTER's AFTER anchor and definition byte-consistent with the CREATE TABLE column.
   - Document which tests remain blocked until SQL is manually reviewed and executed.

6. Implement in reviewable slices.
   - Treat slices as logical scope and commit boundaries, not mandatory stop points after every ordinary endpoint.
   - Complete related ordinary CRUD/query/mapping interfaces in one concentrated functional pass, then add grouped regression/contract coverage.
   - Use test-first implementation only for the critical behaviors classified by `rigorous-delivery`, including state machines, concurrency/idempotency, auth, durable mutation, external callbacks/retries, security-sensitive validation, client-blocking contracts, and reproduced defects.
   - Follow existing code patterns and keep unrelated refactors out.
   - Do not mechanically add environment/config feature flags to a purely additive, backward-compatible capability when old clients omit the new optional field and the old path remains unchanged. In that case, keep the backend capability available and let the product/client decide whether to expose it.
   - Add a feature flag only for a concrete operational need, such as changing existing behavior, billing or availability semantics, durable data mutation/migration, external capacity or cost exposure, irreversible actions, staged traffic, or independent rollback.
   - Before adding a feature flag, record the old-path impact, flag-off and flag-on behavior, owner, expiry/removal condition, and rollback purpose. If no concrete risk justifies it, omit the flag.
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
- **First-party copy is not exempt: no internal terminology in any user-visible string.** The ban also covers text your own team authored — server-side `errorCode`→message mappings, client toasts/labels/validation copy, CLI output shown to end users, notification text, and integration docs that clients copy verbatim. Such copy MUST NOT leak implementation vocabulary: internal state/segment/status names, enum or flag values, table/column/index names, scheduler or quota mechanics, cycle/window/batch internals, provider/adapter/SDK names, migration or "legacy/historical data" bookkeeping, retry/lease/idempotency jargon, or numeric implementation parameters (e.g. hours, TTLs, counts) that the user cannot act on. Write the user's situation in their domain language, then give the next actionable step; if the honest action is "contact support," confirm that a real support path exists, otherwise state the limitation without promising a capability. Examples of blocking defects: `会员当前周期不是标准 720 小时排期（历史会员）`, `报价复用失败: quote status=ORDERED`, `lease_until 未释放，请重试`.
- Enforce this on every touched copy path: read the exact final string a user would see for each code/branch (including the ones you only reworded), record it in the stable-code-to-copy table, and add or update an assertion on the exact expected copy — a test that only checks the error code does not satisfy this rule.
- **指引必须可执行（不许让用户做做不到的事）。** 文案里给出的每一个动作，都要先验证它在**当前状态下真的能执行**；做不到就是阻塞级缺陷。反例：`已有其他会员订单支付中，请先完成或关闭原支付` —— 在途时订单根本不可取消，取消也不会释放占用（占用由渠道状态决定），用户照做只会失败。可用动作只有"等待后重试"或"联系客服"，且承诺的客服/自助路径必须真实存在。管理端（运营/客服）文案同样受此约束：参数不合规要给"缺什么、怎么补"，不能报成"服务暂时不可用"。同时把该文案的**精确断言**写进用例（只断言 errorCode 不算过关）。

7. Verify with real commands.
   - Start the staged smoke/review/full gate after the accepted functional pass is complete; do not interrupt every ordinary endpoint with a full verification cycle.
   - **后端/worker/CLI 改动必须本地起真实程序 + 本地数据库调真实接口**（`creating-pull-requests` 铁律 12）：建一次性库、跑迁移、灌最小数据行、启动二进制、调用真实接口、检查库里的真实数据行。单元测试与绿色套件**不是**验收。修复类要给出 base 版本的**修复前后对照**，并配**判别性对照**（已注册路由 200 vs 未注册路径 404）——鉴权中间件常在路由之前执行，未鉴权时同类路径可能返回完全相同的响应，不能作为"路由是否存在"的证据。触达不到的层面要在交付里明说。
   - **动手前先证明目标代码路径可达**（铁律 13）：确认存在非测试调用方，并确认**当前部署的 SHA** 实际调用的是哪个函数。修不可达代码是无用功。
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

8. Deliver the handoff without repository clutter.
   - Provide the final handoff in chat after implementation and verification stabilize, using the accumulated evidence.
   - Create an API/integration or deployment document in the repository only when the user requested that document or the repository requires it as a product artifact.
   - For deployment-risk work, include rollout order, smoke tests, rollback switch, and what is not guaranteed in the final handoff even when no file is created.

9. Review and red-team before completion.
   - Invoke `rigorous-delivery` for this gate and follow its current-agent review checklists.
   - State the risk tier. It controls each round's depth, not the exit count: every tier and every repository requires three sequential P0/P1-clean rounds against its same final identity. High-risk rounds include separate normal/adversarial work; low/medium-risk rounds may use distinct combined-impact checklists.
   - Code is not "done" until the exact final diff/commit has a `3/3` record and every P0/P1 is fixed/re-verified with evidence. Record and surface P2/P3; they do not block unless the user makes them blocking or they affect safety/security/data integrity.
   - Do not invoke another review workflow that automatically delegates. The current-agent normal and adversarial passes are the canonical gate.
   - The review must check regressions, missing permission checks, deployment ordering, table-not-found behavior, token/user mismatch, rollback behavior, data-access/performance risk, and untested paths.
   - Trace all touched feedback paths—including success, failure, realtime, SSR/BFF, SDK, and bridge paths—from transport to presentation. Search for diagnostic strings, raw bodies, `.message`, `cause`, `stack`, `statusText`, and `err.Error()` entering UI state, props, stores, templates, toasts, notifications, accessibility text, URLs, native bridges, or generated output. Any user-facing passthrough is a blocking P1; exposure of secrets, credentials, tokens, or personal data is P0. A missing source inventory, hostile-text injection test, or required evidence is also an unverified P1. Do not close or ship the accepted scope until it is removed and re-verified.
   - 在支付/退款/状态机/重试等关键业务路径的提案和落地中，要求预先定义最小可用业务日志点：关键入口参数摘要、分支判断/状态迁移、外部网关调用前后、幂等键/乐观锁冲突处理、重试/补偿动作。日志应为结构化、可追溯（如 requestID/traceID/businessID），只打印关键节点，避免热路径高频噪声日志。
   - Fix findings or document residual risks with evidence.
   - Record each round's number, commit SHA/diff identity, independent angle, selected radius, findings, dispositions, and evidence in the shared ledger. Any versioned change resets the record to `0/3`; PR preparation may reuse only a complete `3/3` record for the unchanged final identity.

10. Commit by functional slice.
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

11. Push and PR readiness.
   - Before pushing, rerun `scripts/validate-branch-name.sh "$(git branch --show-current)"`. A rejected branch MUST be renamed and rechecked before any push or PR creation.
   - Run `scripts/validate-workflow-artifacts.sh <base> [head]`. Remove every rejected workflow Markdown file from the commit/PR unless the user or repository explicitly required that exact versioned document; record that exception in the post-create body shown in chat.
   - Push only the frozen commit that passed focused/full tests and the three-round clean-review gate. After push, confirm the remote head SHA exactly matches the reviewed SHA; a push containing a different commit resets the gate.
   - **diff 与推送的身份纪律（通用）**：① 评审与交付的 diff 一律以 **merge-base** 为基（`git diff $(git merge-base HEAD origin/<target>)..HEAD`），不要用目标分支当前 tip 的双点 diff —— 基线漂移会把别人新合入的改动**以删除形式**算到本分支头上；② 推送前复查 merge-base 是否仍等于建分支时的基线：若漂移，求与本分支文件集的交集，为空时用无工作区合并检查（`git merge-tree --write-tree HEAD origin/<target>`）证明无冲突，**不必为了对齐而 rebase**（rebase 只重写 SHA、使已评审的 tree 指纹失效），但交付正文必须写明"相对基线"；③ 推送使用**显式 refspec**（`git push -u origin <branch>`），不要依赖分支已配置的 upstream —— 本地/worktree 分支的 upstream 可能指向主干。
   - Do not ask "要不要提 PR / 可以提 PR 了吗" before the exact final identity has `3/3`, no open P0/P1, and P2/P3 are explicitly surfaced for triage.
   - Treat the `3/3` ledger as the single PR-readiness record. When `creating-pull-requests` runs later, it verifies this record instead of repeating it, unless any commit or diff changed after review.

12. PR and cleanup.
   - If the user asks to create/open/submit a PR, invoke `creating-pull-requests` directly (base 分支由用户指令指定；模板 body 生成后直接创建，不设事前 handoff 停顿); do not hand-roll creation.
   - When no PR was requested, the final report only states the readiness identity (branch, commit SHA, `3/3` gate status) — it does not inline a full PR payload.
   - After the PR is created, remove worktree directories created for this task using safe git worktree cleanup (`git worktree remove <path>` when possible), and verify `git worktree list` no longer shows stale task worktrees.
   - Never remove the user's original repo or unrelated worktrees.

13. Final report.
   - Include the bound issue when one exists; otherwise name the accepted request/sub-item scope. Also include branches/worktrees, commit hashes, key files, explicitly requested product docs, verification commands and results, blocked tests, deployment safety answer, and remaining manual steps.
   - Include the actual commit count and list each commit hash with its module/function scope. If the branch has 1 commit or more than 5 commits, state the explicit user approval that allowed it.
   - For frontend/UI scope, include the affected-UI verification matrix with one row per route/state and responsive variant, plus a visible preview or clickable local link for every required screenshot. Explicitly list any row that could not be exercised; do not collapse multiple unverified pages into a generic “browser test passed” statement.
   - For touched feedback/error paths, include the stable-code-to-copy/UI mapping, unknown-code fallback, automated non-disclosure test result, and screenshot evidence for each visual error state. Explicitly state whether any backend feedback/diagnostic text can still reach a user-facing surface; if that cannot be proven false, do not report the scope complete.
   - Include a three-row review ledger summary per repository: round, exact commit/diff identity, independent angle, P0 count, P1 count, and evidence reference. Anything below `3/3`, any mixed commit identities, or any open P0/P1 means the task remains in progress.
   - When the user has NOT asked for a PR, end with the readiness state only (branch, commit SHA, tree fingerprint, `3/3` gate status, disclosed P2/P3) plus a one-line pointer that the PR payload is ready on request — do not inline the full payload, and do not ask whether to *prepare* it. The payload itself MUST already exist and be reproducible (single source of truth with `rigorous-delivery` Iron rule 12); wait for the user to request creation.
   - List any adjacent issues found but intentionally not implemented.
   - Do not claim full acceptance when SQL, runtime, or real API checks are still blocked.

## Deployment Safety Checklist

Before saying the service can keep running during deployment, verify and document:

- Risky new behavior is behind a justified feature flag; purely additive behavior may ship without one only when old clients omit the new field and the old path remains unchanged.
- Missing new tables do not break old authentication or old pages.
- SQL is not required before deploying code unless that is explicitly accepted.
- When a flag is justified, turning it off disables the risky new path and its owner/removal condition is documented.
- Rollback can be done per repo or per commit.
- Manual SQL execution has backup and review requirements.
- Smoke tests cover both flag-off old behavior and flag-on new behavior.
- 交付依赖**代码之外的状态**（环境变量、控制台开关、密钥、基础设施选项、权限/配额）时，逐项给出四件：**在哪改**（精确入口：控制台路径 / 配置文件 / CLI）、**如何确认已生效**（读什么日志、或执行什么只读查询得到"生效值"）、**如何撤销**（改回什么、删除什么）、**何时执行**（必须先于还是后于代码部署）。只给"变量名 + 目标值"不算交付。

Use precise language: say "旧路径应继续运行 when these conditions hold" instead of promising absolute uptime.
