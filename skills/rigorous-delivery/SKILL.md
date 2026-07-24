---
name: rigorous-delivery
description: Use when the user asks to start a substantial refactor, feature, fix, migration, milestone, or implementation slice; not for light Q&A.
---

# Rigorous Delivery

A discipline for completing substantial tasks with **high accuracy and real proof** — no claims without evidence.

## Iron rules (never violate)

1. **Evidence over assertion.** Any "looks fine / no missing fields / done / unaffected" conclusion MUST be backed by a real artifact: an actual API response or test output. Reading the code is NOT enough to conclude.
2. **Verify through the real API ONLY — never read or mutate the DB to check functionality.** Drive the real endpoint and confirm via its API response. Querying/editing rows directly can hide API-layer bugs and isn't what users/frontends see. (Direct DB access is allowed for ONE thing only: the pre-change backup safety net — never for verification.)
3. **Read-after-write, via API.** After every create/update/delete, immediately call a READ endpoint and confirm the result in its response — not via a DB query.
4. **Edge cases always.** Duplicate op, non-existent entity, concurrent/conflict, empty/null, soft-deleted, finalized/locked state.
5. **Frontend contract check on any response change.** If a response shape might change, find the frontend's type for that DTO, list the fields it expects, and confirm each against a REAL response (mind `omitempty` — verify those in the scenario that produces them). State whether the frontend needs changes and the basis.
6. **Keep evidence auditable without flooding the conversation.** Preserve the exact command and raw output in the current tool log or a task evidence file. In chat, report the literal command, concrete entity/account/port, status code, key response fields, and pass/fail counts. Paste full raw output only when a check fails, the output is short, a disputed finding needs proof, or the user explicitly requests it. Never replace evidence with an unsupported "all green" claim.
7. **Current-agent review + adversarial red-team before "done".** Use risk-tiered review after smoke. By default the current agent performs all implementation, normal review, red-team, and validation sequentially; NEVER invoke Task/Agent/subagent tools unless the user explicitly requests delegation in the current task. Keep review quality by running two distinct passes with fresh checklists: (1) NORMAL review for requirements, correctness, contract, quality, data access and performance; (2) RED-TEAM for hostile inputs, auth bypass, cross-account/IDOR, concurrency, malformed payloads, contract violations, injection, and server-owned field override. Low/medium risk normally needs one combined impact pass; high risk requires both separate passes. Record every finding as **fixed**, **rejected with evidence**, or **open**. After a fix, re-run only the affected checklist and tests unless the fix changed the broader review radius.
8. **Concurrency, data integrity & cross-endpoint consistency are first-class — and CANNOT be parked as a deferred P3.** Any write that does **read-modify-write on shared mutable state** (a JSONB array/object overwritten whole, a counter, an upsert, read-list-then-replace) is a data-loss risk until proven safe with a transaction + row lock / atomic op. The red-team MUST actually **fire N concurrent real requests** at it and confirm the final state keeps all N (no lost / overwritten / orphaned records) — "it looks atomic" code reasoning does NOT count. A confirmed **concurrent data-loss / orphaned-resource / silent-overwrite** finding is **P1, never deferred** — never "push now, fix the data loss later". The normal reviewer ALSO checks: (a) **cross-endpoint representation consistency** — the same resource returned by create/upload vs read vs list must agree (a computed field, a signed-URL download flag, an enum, a derived URL); (b) **async failure paths** — a fire-and-forget write that isn't awaited, leaving a half-written record or a misleading UI when it fails; and (c) **server-owned field integrity** — caller-provided metadata/JSON/map values cannot override fields that drive auth, idempotency, status, ownership, recovery, or lookup semantics.
9. **Completed scope + pushed requires one reusable risk-tiered review record.** Run the matching PR review gate against the latest commit before saying the accepted scope is done or suggesting a PR. Reuse that record while the reviewed diff is unchanged. High-risk changes require the `4b-full` sequential matrix; low/medium-risk changes use one combined impact pass plus focused tests. Scope review to the diff and genuinely coupled flows, not the whole repository.
10. **Bind existing issues; never manufacture one for the workflow.** If the user provides an issue or a clear matching tracker issue already exists, bind the current branch to that issue. If no issue exists, continue with the accepted user request as scope and do not create a tracker issue unless the user explicitly asks. For issue-driven work, keep one issue or explicitly accepted sub-item set per branch/PR. If work reveals a second issue, dependency, or adjacent risk, document it as follow-up and stop before implementing it in the same branch unless the user explicitly approves combining scopes.
11. **Finish the functional pass before polishing.** After scope and high-risk design are clear, implement the accepted functional surface as one concentrated pass. Do not interrupt every ordinary endpoint to rewrite Markdown, polish prose, or run a full review cycle. Consolidate ordinary regression tests, review, evidence, and the final chat handoff after the functional pass is complete. Critical paths still follow the test policy in step 0.

## DB & credentials — per project, from env

Different projects use different DBs/creds. **Read them from the project `.env`; never hardcode.**
- API login creds (for verification): `.env` `AUTH_ACCOUNTS` (JSON array of {username,password}) or legacy `AUTH_USERNAME`/`AUTH_PASSWORD`.
- Server port (for verification): `.env` `SERVER_PORT`.
- DB connection (`.env` `DB_NAME`/`DB_USER`/`DB_HOST`/`DB_PORT`, e.g. `docker exec <pg> psql -U <user> -d <db>`): used **only for the pre-change backup**, never for verification.
- Example (adapt per project):
  ```bash
  CREDS=$(grep -E "^AUTH_ACCOUNTS=" .env | sed -E 's/^AUTH_ACCOUNTS=//' \
    | python3 -c 'import sys,json;a=json.load(sys.stdin)[0];print(a["username"]);print(a["password"])')
  ```
- If a non-interactive login is required, ask the user to run it via `! <cmd>`.

## Flow

### 0. Classify the task
- **Critical behavior → TDD first.** Write a failing test before implementation when changing a state machine, concurrency/idempotency behavior, auth/authorization, durable mutation or migration, external callback/retry boundary, security-sensitive validation, public contract whose breakage would block clients, or a reproduced defect.
- **Ordinary behavior → batch implementation, then grouped regression.** Routine CRUD/query/mapping endpoints may be implemented together after requirements are clear, then covered by focused table-driven or contract tests after the complete functional pass. Do not force one RED/GREEN cycle per ordinary endpoint.
- If the user explicitly requests broader TDD, follow that request. Never use the ordinary-path allowance to skip tests entirely or to downgrade a critical path.
- **refactor → behavior-preserving slices.** Output must be byte-identical contract. Split into independently verifiable slices (by entity / table / feature); each slice is implement → verify → commit.

### 1. Plan (before touching code)
- Recon the change surface: grep references, read key code, inspect DB schema. Know the full blast radius before editing.
- Check for a user-provided or clearly matching existing tracker issue. Bind it when present. If none exists, name the accepted request or sub-item set this branch is allowed to complete and proceed without creating an issue. Keep adjacent issues out of the implementation plan unless the user explicitly approved a combined branch.
- Decompose into implementation, verification, and finalization phases in the working context. Do not use repository Markdown as the default planning or tracking mechanism.
- Preserve commands and raw evidence in tool output or a temporary ledger outside the repository. Agent workflow Markdown MUST NOT be staged or committed unless the user requested that exact document or the repository explicitly requires it as a versioned product artifact.
- For scope or high-risk forks, use AskUserQuestion — don't decide unilaterally.

### 2. Safety net (before destructive ops)
- Before dropping tables/columns or any irreversible migration: back up (pg_dump the whole DB or affected tables) into the project's `db-backups/`, add it to `.gitignore`, and record the restore command.

### 3. Implement
- Complete the accepted business functionality before the documentation/polish pass. Batch related ordinary endpoints and resolve compiler/runtime integration issues without pausing after each endpoint for documentation or a full test cycle.
- For critical behavior identified in step 0, keep the smallest relevant RED/GREEN loop inside the implementation pass. This exception protects correctness without turning every endpoint into its own ceremony.
- Use the compiler to find all references (delete a field → build errors → fix each). Don't rely on grep alone for completeness.
- Preserve the outward API contract; don't casually delete DTO fields. If a field must go, do the frontend check (Iron rule 5).
- 关键链路（支付、账务、状态机、重试、并发）必须补齐最小关键业务日志：入口参数摘要、状态迁移、外部网关请求前后、幂等/锁冲突、回滚或补偿分支。日志要求可检索（trace/request/businessID）、结构化、低噪声，避免在高频热路径加 `fmt.Printf` 式噪音。

### 4. Verify — staged: smoke → review → full (API ONLY)
Run these in order. Do NOT jump to "done" after the smoke step.

Start this staged gate after the accepted functional pass is complete. Add grouped regression/contract coverage for ordinary behavior here; critical behavior should already have its focused RED/GREEN tests from step 0.

**Frontend / UI verification MUST run in a HEADED browser (`agent-browser --headed`), never headless.** Confirm the dev server is running the current code; restart a stale long-lived dev server when changes do not appear. Reuse one browser session across related cases and close it when verification ends.

**4a. Smoke first (mandatory gate, not an optimization).** Run a quick real-API happy path plus read-after-write against a server built/restarted from the current change. If smoke fails, stop and fix before review. Record the command, concrete data, status, and key response fields under Iron rule 6.

**4b. Current-agent review passes (Iron rule 7) — before claiming done.**
- **Risk tier first:** State low, medium, or high. Low/medium risk uses one combined impact-radius checklist unless security/data integrity or the user calls for red-team. High risk requires separate normal and adversarial passes, both executed by the current agent without delegation.
- **Normal pass:** requirements/correctness, API contract, code quality, and data-access/performance sanity: N+1, request amplification, missing indexes/full scans, hot-path work, and duplicate requests. Use Network request count or query logs when the touched path is runnable.
- **Payment/idempotency reviewer checklist:** if the diff adds or changes idempotency keys, reservation/lock tables, provider retries, or metadata lookups, reviewers must test hostile metadata (`idempotency_key`, `status`, `customer_id`, `recovery_*`, case/space variants), fresh pending, stale pending, succeeded pointer, provider failure release, duplicate concurrent requests, and crash windows before/after provider success. If a Stripe/third-party provider idempotency key format changes, reviewers must check backward compatibility for in-flight pre-deploy retries that reached the provider but not local persistence. A "unique index exists" answer is incomplete.
- **Adversarial pass ("扮坏人"):** start a fresh checklist after the normal pass and try to BREAK the change with hostile/boundary inputs, auth bypass, concurrent/duplicate operations, empty/null, malformed/oversized payloads, contract violations, injection, and caller metadata poisoning. For read-modify-write/counter/upsert paths, fire N concurrent real requests and verify final state. Compare create/write responses with later read/list representations.
- **Incremental re-review:** Fix every CONFIRMED P0-P2 finding → re-verify the fix via focused tests/API evidence → re-run only the reviewer/red-team slice that found it, scoped to the new diff plus that finding. Do not re-run full normal+red-team+4b-full just because a narrow fix landed. P3 can be handled by local verification plus explicit user triage unless it affects safety/security/data integrity.

**4b-full. Sequential multi-dimensional impact matrix — REQUIRED when the user asks for a thorough review and before suggesting a PR for a substantial high-risk change. Low/medium risk uses the combined pass unless the user asks for full review.** Do not turn this into a whole-repository audit. Define the review radius from the actual diff:
- Always review changed files, directly called code, shared DTOs/contracts, persistence writes/reads touched by the change, and tests.
- Review upstream/downstream only when the coupling is real. Example: if the diff touches payment, inspect payment entry points, course/order state handoff, payment-success/failure/retry/refund/subscription lifecycle as applicable; do not review unrelated login, student profile, or other modules unless the diff calls them or changes their contract.
- State the selected radius and why adjacent areas were excluded.

The current agent checks applicable dimensions sequentially in one matrix. Do not spawn separate agents. Combine dimensions that share the same files/evidence and mark non-applicable rows with a short reason:
- **Security** — authz/role gates, IDOR / cross-account, injection, path traversal, MIME / upload-type bypass, signed-URL / secret / internal-path leakage, stored XSS.
- **Data lifecycle & consistency** — create / delete / orphan, DB ↔ external object-store consistency, concurrency final-state, soft-delete, idempotency, missed read/write paths (e.g. an unsigned/unhydrated path).
- **Payment/idempotency lifecycle** — reservation freshness/staleness, provider idempotency-key reuse, provider idempotency-key backward compatibility across deploys, stale recovery vs permanent 409, server-owned metadata fields protected from caller override, fallback lookup source-of-truth.
- **Frontend robustness / UX / a11y** — loading / error / disabled states, desktop vs mobile parity, edge inputs (empty / oversized / unsupported type / network drop), client-side pre-validation, blob / memory cleanup (`createObjectURL`→`revokeObjectURL`), keyboard / aria, fire-and-forget failure paths.
- **Integration / regression / contract** — front↔back DTO field alignment (incl. internal fields that must NOT leak to the client), breakage of adjacent features, interaction with sync / other services, DI wiring, error-code mapping.
Use real API evidence when the impacted surface is runnable; otherwise record why focused tests are the practical evidence. Return one deduplicated P0-P3 table with file:line, disposition, and evidence. Do not repeat checks already covered by the normal/red-team passes; reference their evidence instead.

**4c. Full / pressure verification.** Run applicable edge cases, every P0-P2 regression case, relevant suites, and frontend contract checks. Use table-driven tests or one scripted API matrix when cases share setup; report each case's input and observed result without duplicating common setup/output. Do not repeat unrelated batteries after a narrow fix.

### 4d. Loop until PR-ready — don't stop mid-way to ask "没问题吧?"
A substantial task is NOT done when the first round of fixes lands. Run autonomously: smoke → risk-tiered review → fix P0/P1/P2 → re-run only the affected checklist/tests → repeat until clean. Batch genuine product/scope decisions into one user question. Stop only when the work is PR-ready, fixes are re-verified, compact evidence is reported, and follow-ups are triaged.

### 5. Check off acceptance (with evidence)
- Report acceptance in the final chat handoff after implementation and staged verification stabilize. Create versioned API, integration, or deployment documentation only when it is an explicitly required product deliverable.
- Two states only: `[x]` (done — append HOW it was verified) / `[ ]` (not done). No `[~]`.
- Anything genuinely achieved (even if implemented in an earlier milestone) → `[x]`.
- Do NOT write "why it wasn't done" justifications in the doc. Tell the user verbally and let them decide.
- Don't dress up "deferred to a future milestone" as done.

### 6. Commit
- Commit each verified functional slice. Exclude agent-generated plan, spec, design, progress, tracker, evidence, handoff, and final-summary Markdown from commits and PRs.
- If the user explicitly requested a versioned product document, or the repository requires one, commit that exact document with its related implementation rather than as a workflow-only commit.
- Commit message states how it was verified; no future-work narration; end with the project's Co-Authored-By line.
- Confirm before outward-facing/irreversible actions; follow the project's branch conventions.
- Follow the branch-name contract in `rigorous-feature-delivery`: `<group>/<english-kebab-case-description>`, ASCII English only, no usernames, tracker IDs, issue numbers, Chinese, spaces, or underscores. Validate the proposed name before branch/worktree creation and again before push.
- Before committing, check that the diff only implements the bound issue, accepted sub-item set, or accepted untracked request. If the diff contains an adjacent scope, split it out or get explicit user approval before commit/push.
- After pushing a branch for a completed scope, run the required risk-tiered PR review gate before suggesting or preparing a PR. High-risk changes still need 4b-full; low/medium-risk changes may cite the comprehensive impact-radius reviewer if the latest commit already passed and no code changed after it.

## Definition of Done — keep one compact checklist in the completion reply
A "done" claim missing any line below is invalid:
- [ ] 4a smoke evidence recorded — command + concrete data + status/key fields against current build
- [ ] risk tier stated (low/medium/high) and matching review gate used
- [ ] current-agent normal pass completed; high-risk current-agent adversarial pass completed or reason not required recorded
- [ ] each finding has severity, disposition, focused re-verification, and evidence reference
- [ ] 4c edge-case matrix completed for applicable cases
- [ ] data-access/performance evidence recorded when touched paths are runnable
- [ ] relevant test counts and frontend contract basis recorded; failures include raw output/reference
- [ ] latest commit passed the reusable PR gate; high-risk changes have one deduplicated 4b-full matrix and no open P0/P1

## Anti-patterns (forbidden)
- Interrupting every ordinary CRUD/query endpoint for a separate RED/GREEN cycle, progress-document edit, and review pass when no critical-risk trigger applies.
- Rewriting plan/progress Markdown throughout implementation when no user or repository rule requires a live document.
- Staging or committing agent workflow Markdown because another skill generated it, because it already exists in the worktree, or because it makes the commit look documented.
- Concluding "no missing fields / frontend unaffected" from code alone, without a real response.
- Verifying functionality via the DB at all (querying OR editing rows) instead of the real API — DB is for the backup only.
- Marking undone work `[x]`, or reframing undone work as "merged into a future milestone" to look complete.
- Deleting a DTO field without the frontend check.
- Skipping read-after-write or edge cases because "it obviously works".
- Reporting only "all green / verified" without commands, concrete data, observed values, and counts.
- Using vague/unnamed test data. Always name the concrete entity (real id + name) and account so the user can audit and reproduce.
- Declaring "done" without the required current-agent normal/adversarial passes (Iron rule 7 / step 4b).
- Treating the red-team ("扮坏人") pass as optional for high-risk changes because the smoke test passed or the suite is green.
- Merging normal review and red-team into one superficial pass, or rejecting a finding without evidence.
- Claiming "no response change, nothing to paste" to skip read-after-write evidence — read-after-write proof is ALWAYS required for any write.
- Declaring a read path fine without counting the REAL requests — missing an N+1: per-row / per-parent fan-out on the client, or per-item queries on the server. "The code looks efficient" is not evidence; the Network count / query log is.
- Deleting or losing raw evidence before disputed/failed checks are resolved.

## Red flags — STOP, you're about to under-verify
- Using "batch implementation" as a reason to skip focused tests for state machines, concurrency/idempotency, auth, durable mutation, external retries, public contract breakage, or reproduced defects.
- "It builds and a unit test passes — ship it."
- "Smoke passed, no need for the red-team pass."
- "The normal pass found nothing, so the required adversarial pass can be skipped."
- About to report "verified / all green" with no command, concrete data, result fields, or test counts.
- Test data you can't name (no real id/name).
- A page load that fires one request per row / per parent, or a list endpoint that re-queries per item — and you "verified" it without counting the REAL requests (Network panel / query log).
- A non-transactional read-modify-write (JSONB array / counter / list overwritten whole) you're about to call a P3 to "push now" — concurrent data loss is **P1**: prove it safe by firing N concurrent real requests, or fix it before push (Iron rule 8).
- A create/upload response whose representation differs from the read/list endpoint for the same resource (a flag, a computed field, a signed-URL param) — that inconsistency is a real bug, not cosmetic.
- A frontend write fired without `await` (fire-and-forget) whose failure path leaves a half-written record or a misleading UI — verify the failure path, don't just the happy path.
- About to ask the user "建 PR 吗? / 可以提 PR 了" for a high-risk change when only the standard reviewer + red-team ran — the multi-dimensional impact-radius review (4b-full, front+back when impacted) is the GATE before suggesting a PR; run it and show the consolidated table first.
- About to verify a frontend/UI change in a HEADLESS browser — re-run with `agent-browser --headed`. If a change does not appear, restart a potentially stale dev server and re-test.
- An issue-driven branch contains fixes for a second tracker issue because it was "nearby" or "overlapped" — split it or ask first. Traceability beats opportunistic bundling.

All of these mean: run the staged verify — **smoke → current-agent risk-tiered review → full** — and report compact, reproducible evidence. Never delegate automatically; Task/Agent/subagent tools require an explicit request from the user in the current task.
