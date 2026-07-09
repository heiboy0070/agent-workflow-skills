---
name: rigorous-delivery
description: Use when the user asks to START a substantial work task (refactor / feat / fix / migration) — not for light Q&A. Enforces a high-accuracy delivery loop — plan → implement → verify with REAL API + DB (read-after-write, edge cases, frontend field check) → check off acceptance WITH EVIDENCE → commit. Refactor = behavior-preserving slices + backup before destructive ops. feat/fix = TDD first. DB credentials/connection are per-project — always read from the project's .env, never hardcode. Triggers on phrases like "开始做X", "start implementing", "执行这个里程碑/切片".
---

# Rigorous Delivery

A discipline for completing substantial tasks with **high accuracy and real proof** — no claims without evidence.

## Iron rules (never violate)

1. **Evidence over assertion.** Any "looks fine / no missing fields / done / unaffected" conclusion MUST be backed by a real artifact: an actual API response or test output. Reading the code is NOT enough to conclude.
2. **Verify through the real API ONLY — never read or mutate the DB to check functionality.** Drive the real endpoint and confirm via its API response. Querying/editing rows directly can hide API-layer bugs and isn't what users/frontends see. (Direct DB access is allowed for ONE thing only: the pre-change backup safety net — never for verification.)
3. **Read-after-write, via API.** After every create/update/delete, immediately call a READ endpoint and confirm the result in its response — not via a DB query.
4. **Edge cases always.** Duplicate op, non-existent entity, concurrent/conflict, empty/null, soft-deleted, finalized/locked state.
5. **Frontend contract check on any response change.** If a response shape might change, find the frontend's type for that DTO, list the fields it expects, and confirm each against a REAL response (mind `omitempty` — verify those in the scenario that produces them). State whether the frontend needs changes and the basis.
6. **Show the evidence to the user — not just in the tool log.** Tool outputs are INVISIBLE to the user; verification that lives only there is unauditable and indistinguishable from fabrication. Paste the artifact **VERBATIM and inline in this chat reply** — copied unedited from the tool output (status line + body), NOT retyped, summarized, truncated, or elided with "…"; a pointer to a file / doc / tool log does NOT count. Include the concrete entity (real id/name), the account/port used, and the **literal** reproduce command you ran (real endpoint + real id + a runnable login) — placeholder templates don't count. "raw test output" = the full command + the runner's complete output for the relevant tests, not just a trailing `PASS`/`ok`. "All passed / verified" without the raw artifact does NOT count.
7. **Independent + adversarial review before "done".** Self-verification is not enough. After smoke passes, use risk-tiered review. A "subagent" = a fresh, separate agent invocation (Task/Agent tool) that did NOT write the code — reviewing it yourself under a "review" heading does NOT count; cite the invocation/agent id. Low/medium-risk changes may use one comprehensive impact-radius reviewer. High-risk changes (payments/billing/money, auth/authorization, durable state machines, concurrency, external webhooks/queues, migrations, privacy/security contracts) require TWO SEPARATE subagents: (1) a NORMAL reviewer (requirements / correctness / contract / quality / **data-access & performance — N+1, request amplification, full-table scans**, judged from a real Network count or query log); (2) a RED-TEAM given the actual diff + the running endpoint + creds and told ONLY to BREAK it via the REAL API (hostile & boundary inputs, auth bypass, cross-account/IDOR via a second `AUTH_ACCOUNTS` entry against another account's entity, concurrent/duplicate ops, empty/null, malformed/oversized payloads, contract violations, injection, user-controlled metadata/JSON/map overriding server-owned fields) — a red-team that only reasons over a summary does not count. For EVERY red-team finding, record its disposition: **fixed** (with re-verify evidence) or **rejected** (with a real artifact — hitting the exact attack, against the current build, pasted verbatim — disproving it) — "not confirmed" asserted without evidence is forbidden; a finding stands until disproven. After fixing P0-P2 findings, re-run only the reviewer/red-team slice that found the issue, scoped to the new diff plus the original finding; do not repeat a full review unless code changed outside that slice. "Smoke / unit tests passed" does NOT exempt this.
8. **Concurrency, data integrity & cross-endpoint consistency are first-class — and CANNOT be parked as a deferred P3.** Any write that does **read-modify-write on shared mutable state** (a JSONB array/object overwritten whole, a counter, an upsert, read-list-then-replace) is a data-loss risk until proven safe with a transaction + row lock / atomic op. The red-team MUST actually **fire N concurrent real requests** at it and confirm the final state keeps all N (no lost / overwritten / orphaned records) — "it looks atomic" code reasoning does NOT count. A confirmed **concurrent data-loss / orphaned-resource / silent-overwrite** finding is **P1, never deferred** — never "push now, fix the data loss later". The normal reviewer ALSO checks: (a) **cross-endpoint representation consistency** — the same resource returned by create/upload vs read vs list must agree (a computed field, a signed-URL download flag, an enum, a derived URL); (b) **async failure paths** — a fire-and-forget write that isn't awaited, leaving a half-written record or a misleading UI when it fails; and (c) **server-owned field integrity** — caller-provided metadata/JSON/map values cannot override fields that drive auth, idempotency, status, ownership, recovery, or lookup semantics.
9. **Issue-complete + pushed requires risk-tiered impact-radius review.** If you believe the issue is complete and the branch has been pushed, run the matching PR review gate before saying the issue is done or asking whether to create a PR. High-risk changes require `4b-full` multi-dimensional impact-radius review; low/medium-risk changes may use one comprehensive impact-radius reviewer plus focused tests. This is not a whole-repository audit: scope it to the current diff and its high-coupling upstream/downstream flows.
10. **One issue per branch/PR by default.** For issue-driven work, bind the current branch to one tracker issue or one explicitly accepted sub-item set. If work reveals a second issue, dependency, or adjacent risk, document it as follow-up and stop before implementing it in the same branch unless the user explicitly approves combining scopes.

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
- **feat / fix → TDD first.** Write a failing test that expresses the intended behavior → implement until green → then real-API verify.
- **refactor → behavior-preserving slices.** Output must be byte-identical contract. Split into independently verifiable slices (by entity / table / feature); each slice is implement → verify → commit.

### 1. Plan (before touching code)
- Recon the change surface: grep references, read key code, inspect DB schema. Know the full blast radius before editing.
- Name the single issue or accepted sub-item set this branch is allowed to complete. Keep adjacent issues out of the implementation plan unless the user explicitly approved a combined branch.
- Decompose into slices/phases. Write a plan doc (change list + verification plan + risks).
- For scope or high-risk forks, use AskUserQuestion — don't decide unilaterally.

### 2. Safety net (before destructive ops)
- Before dropping tables/columns or any irreversible migration: back up (pg_dump the whole DB or affected tables) into the project's `db-backups/`, add it to `.gitignore`, and record the restore command.

### 3. Implement
- Use the compiler to find all references (delete a field → build errors → fix each). Don't rely on grep alone for completeness.
- Preserve the outward API contract; don't casually delete DTO fields. If a field must go, do the frontend check (Iron rule 5).
- 关键链路（支付、账务、状态机、重试、并发）必须补齐最小关键业务日志：入口参数摘要、状态迁移、外部网关请求前后、幂等/锁冲突、回滚或补偿分支。日志要求可检索（trace/request/businessID）、结构化、低噪声，避免在高频热路径加 `fmt.Printf` 式噪音。

### 4. Verify — staged: smoke → review → full (API ONLY)
Run these in order. Do NOT jump to "done" after the smoke step.

**Frontend / UI verification MUST run in a HEADED browser (`agent-browser --headed`), never headless.** The user wants to SEE the verification happen on screen — a visible run is auditable, a hidden one isn't. Whenever you drive a UI to verify (smoke, edge cases, panel reviewers, re-checks), open it with `--headed`; if a subagent does the driving, instruct it to use `--headed` too. And confirm the dev server is running the CURRENT code — a long-lived `next dev` can go HMR-stale (a fix "fails" because the old build is still served); restart it if a change doesn't show up (mind the cac NODE_OPTIONS double-space bug — start with a single `--require /tmp/cac-combined-preload.js` and run `next dev` directly, not via `npm run`).

**4a. Smoke first (mandatory gate, not an optimization).** Quick real-API happy-path + read-after-write on the main endpoint, run against a server **built/restarted from the current change** (paste the restart command output or a version/health line proving the running binary matches the noted commit). You may not skip smoke by "going straight to full"; if smoke fails, stop and fix before review. Paste the raw request+response (Iron rule 6).

**4b. Independent review via subagent (Iron rule 7) — before claiming done.**
- **Risk tier first:** State whether the change is low, medium, or high risk. Low/medium-risk changes use one comprehensive impact-radius reviewer unless the user asks for red-team or the code touches security/data integrity. High-risk changes (payments/billing/money, auth/authorization, durable state machines, concurrency, external webhooks/queues, migrations, privacy/security contracts) require both normal reviewer and red-team.
- **Normal reviewer subagent:** requirements/correctness, API contract, code quality, **and data-access / performance sanity** — N+1 (a page or list that fires one request per row / per parent on the client; a server loop that queries per item), request amplification, missing-index / full-table scans, work added to startup or hot paths, duplicate or redundant requests. Judge from REAL evidence — the frontend Network panel request COUNT, or the server SQL / query log — NOT from reading code.
- **Payment/idempotency reviewer checklist:** if the diff adds or changes idempotency keys, reservation/lock tables, provider retries, or metadata lookups, reviewers must test hostile metadata (`idempotency_key`, `status`, `customer_id`, `recovery_*`, case/space variants), fresh pending, stale pending, succeeded pointer, provider failure release, duplicate concurrent requests, and crash windows before/after provider success. If a Stripe/third-party provider idempotency key format changes, reviewers must check backward compatibility for in-flight pre-deploy retries that reached the provider but not local persistence. A "unique index exists" answer is incomplete.
- **Red-team subagent ("扮坏人") for high-risk or explicitly requested cases:** explicitly tasked to BREAK the change — hostile/boundary inputs, auth bypass, concurrent/duplicate ops, empty/null, malformed/oversized payloads, contract violations, injection, caller metadata poisoning of server-owned fields. Goal = surface a failure or hole. Also drive realistic load (open the list / detail view the change powers, with a representative number of rows) and watch the Network panel / query log for a request storm or N+1. **For any read-modify-write / JSONB-array / counter / upsert write, actually FIRE N concurrent real requests and assert the final state keeps all N** (Iron rule 8) — a lost/overwritten/orphaned record is a P1, not a footnote. Also diff the **create/upload response vs the read response** for the same resource — any field/flag mismatch is a real bug.
- **Incremental re-review:** Fix every CONFIRMED P0-P2 finding → re-verify the fix via focused tests/API evidence → re-run only the reviewer/red-team slice that found it, scoped to the new diff plus that finding. Do not re-run full normal+red-team+4b-full just because a narrow fix landed. P3 can be handled by local verification plus explicit user triage unless it affects safety/security/data integrity.

**4b-full. Multi-dimensional impact-radius review panel — REQUIRED (a) when the user asks for a thorough / 全方面 / comprehensive review, AND (b) by default as the GATE before you prompt the user to create a PR for any substantial high-risk change. For low/medium-risk changes, one comprehensive impact-radius reviewer plus focused tests is enough unless the user asks for the panel.** Do NOT just re-run the same reviewer that only re-checks the reported issue — that's "只盯局部". Also do NOT turn this into a whole-repository audit. Define the review radius from the actual diff:
- Always review changed files, directly called code, shared DTOs/contracts, persistence writes/reads touched by the change, and tests.
- Review upstream/downstream only when the coupling is real. Example: if the diff touches payment, inspect payment entry points, course/order state handoff, payment-success/failure/retry/refund/subscription lifecycle as applicable; do not review unrelated login, student profile, or other modules unless the diff calls them or changes their contract.
- Each reviewer must state the selected radius and why anything adjacent was excluded.

Fan out a PANEL of independent reviewers only for high-risk or explicitly requested full-review cases, **one per dimension**, each auditing the whole impacted feature surface (not unrelated modules) from its own angle, IN PARALLEL, then consolidate. Cover (add/drop dimensions to fit the change):
- **Security** — authz/role gates, IDOR / cross-account, injection, path traversal, MIME / upload-type bypass, signed-URL / secret / internal-path leakage, stored XSS.
- **Data lifecycle & consistency** — create / delete / orphan, DB ↔ external object-store consistency, concurrency final-state, soft-delete, idempotency, missed read/write paths (e.g. an unsigned/unhydrated path).
- **Payment/idempotency lifecycle** — reservation freshness/staleness, provider idempotency-key reuse, provider idempotency-key backward compatibility across deploys, stale recovery vs permanent 409, server-owned metadata fields protected from caller override, fallback lookup source-of-truth.
- **Frontend robustness / UX / a11y** — loading / error / disabled states, desktop vs mobile parity, edge inputs (empty / oversized / unsupported type / network drop), client-side pre-validation, blob / memory cleanup (`createObjectURL`→`revokeObjectURL`), keyboard / aria, fire-and-forget failure paths.
- **Integration / regression / contract** — front↔back DTO field alignment (incl. internal fields that must NOT leak to the client), breakage of adjacent features, interaction with sync / other services, DI wiring, error-code mapping.
Each panel reviewer hits the REAL API with named evidence when the impacted surface has a runnable endpoint, or explains why unit/integration tests are the only practical evidence for that slice, and returns P0–P3 + file:line; keep the standard normal-reviewer + red-team too. Then **YOU consolidate ALL findings into ONE severity-ranked table** and present scope choices to the user (fix now vs separate ticket) — never silently drop or unilaterally decide. Goal: review the relevant impacted surface multi-angle so a later **external** reviewer finds nothing material in that radius you didn't.

**4c. Full / pressure verification.** The complete edge-case battery (Iron rule 4) + every P0-P2 case reviewers/red-team surfaced + the relevant test suite (for example `go test ./...` when practical, or focused package suites when full suite is blocked/baseline-flaky) + frontend field check against a real response when response contracts changed (Iron rule 5). All runnable API checks via real API, with raw evidence pasted (Iron rule 6). **Each edge case gets its OWN pasted artifact** — reusing the 4a happy-path as edge-case evidence is forbidden. Each behavior-changing slice/phase gets focused 4a–4c evidence; do not repeat unrelated review/test batteries when the new code only touches a narrow finding.

### 4d. Loop until PR-ready — don't stop mid-way to ask "没问题吧?"
A substantial task is NOT done when the first round of fixes lands. RUN THE LOOP autonomously: smoke → required risk-tiered review → fix every P0/P1/P2 → **re-run only the reviewer/red-team slice on the FIX itself** (a fix can introduce a new hole or a symmetric miss — e.g. patching `selectDate` but forgetting `navigateWeek`) → repeat until the impacted slice is clean AND there are no open P0/P1/P2. Do ALL the non-decision work yourself inside this loop — do not bounce back to the user after each round with "确定没问题吗? / 都 OK 了吗?", which just offloads verification onto them. The ONLY reason to pause is a genuine **human decision** (product semantics, scope trade-off, a deliberate defer of a real issue); **batch those and ask in ONE message at the end** (do the non-decision items first, leave only the decisions). Stop and hand off for acceptance only when the work is truly PR-ready: required review gate passed, fixes re-verified (headed browser for UI when applicable), evidence pasted, follow-ups triaged. "I'll ask the user if it's fine" is not a substitute for looping it to clean.

### 5. Check off acceptance (with evidence)
- Two states only: `[x]` (done — append HOW it was verified) / `[ ]` (not done). No `[~]`.
- Anything genuinely achieved (even if implemented in an earlier milestone) → `[x]`.
- Do NOT write "why it wasn't done" justifications in the doc. Tell the user verbally and let them decide.
- Don't dress up "deferred to a future milestone" as done.

### 6. Commit
- Commit each verified slice; docs go WITH their task's commit (don't commit docs alone).
- Commit message states how it was verified; no future-work narration; end with the project's Co-Authored-By line.
- Confirm before outward-facing/irreversible actions; follow the project's branch conventions.
- Branch names must describe the functional change, not tracker IDs or issue numbers, unless the user explicitly requests otherwise.
- Before committing issue-driven work, check that the diff only implements the bound issue or accepted sub-item set. If the diff contains another issue's scope, split it out or get explicit user approval before commit/push.
- After pushing a branch for a completed issue, run the required risk-tiered PR review gate before suggesting or preparing a PR. High-risk changes still need 4b-full; low/medium-risk changes may cite the comprehensive impact-radius reviewer if the latest commit already passed and no code changed after it.

## Definition of Done — your completion reply MUST contain this filled checklist
A "done" claim missing any line below is invalid:
- [ ] 4a smoke evidence pasted (verbatim, inline) — against current build
- [ ] risk tier stated (low/medium/high) and matching review gate used
- [ ] normal-reviewer subagent: invocation/agent id + verdict
- [ ] red-team subagent for high-risk changes, or explicit reason it was not required: invocation/agent id + each finding with disposition (fixed+re-verify / rejected+artifact) + final clean re-run's agent id + its pasted no-findings output
- [ ] 4c full edge-case battery: one pasted artifact per case
- [ ] data-access / performance sanity: real evidence pasted (frontend Network request COUNT, or server query log) showing no N+1 / request amplification on the touched read paths
- [ ] test suite output pasted; frontend field check stated with basis
- [ ] before suggesting a PR: required risk-tiered PR gate ran on the latest commit; for high-risk changes, 4b-full multi-dimensional impact-radius review ran (front+back when impacted) and was consolidated into one severity table, with no open P0/P1

## Anti-patterns (forbidden)
- Concluding "no missing fields / frontend unaffected" from code alone, without a real response.
- Verifying functionality via the DB at all (querying OR editing rows) instead of the real API — DB is for the backup only.
- Marking undone work `[x]`, or reframing undone work as "merged into a future milestone" to look complete.
- Deleting a DTO field without the frontend check.
- Skipping read-after-write or edge cases because "it obviously works".
- Reporting verification as a summary ("all green / verified, no side effects") WITHOUT pasting the raw request + response / test output into your reply — the user cannot see tool results, so an unshown verification is indistinguishable from a fabricated one.
- Using vague/unnamed test data. Always name the concrete entity (real id + name) and account so the user can audit and reproduce.
- Declaring "done" on self-verification alone — skipping the independent normal + red-team subagent review (Iron rule 7 / step 4b).
- Treating the red-team ("扮坏人") pass as optional for high-risk changes because the smoke test passed or the suite is green.
- A fake "subagent" = reviewing your own code under a heading; the red-team reasoning over a summary instead of hitting the real API; deciding findings are "not confirmed" without an artifact.
- Claiming "no response change, nothing to paste" to skip read-after-write evidence — read-after-write proof is ALWAYS required for any write.
- Declaring a read path fine without counting the REAL requests — missing an N+1: per-row / per-parent fan-out on the client, or per-item queries on the server. "The code looks efficient" is not evidence; the Network count / query log is.
- Putting evidence in a file/doc/QA log instead of inline in the reply; eliding long output with "…".

## Red flags — STOP, you're about to under-verify
- "It builds and a unit test passes — ship it."
- "Smoke passed, no need for the red-team pass."
- "I reviewed it myself; a subagent review is overkill."
- About to report "verified / all green" with no raw request+response pasted.
- Test data you can't name (no real id/name).
- A page load that fires one request per row / per parent, or a list endpoint that re-queries per item — and you "verified" it without counting the REAL requests (Network panel / query log).
- A non-transactional read-modify-write (JSONB array / counter / list overwritten whole) you're about to call a P3 to "push now" — concurrent data loss is **P1**: prove it safe by firing N concurrent real requests, or fix it before push (Iron rule 8).
- A create/upload response whose representation differs from the read/list endpoint for the same resource (a flag, a computed field, a signed-URL param) — that inconsistency is a real bug, not cosmetic.
- A frontend write fired without `await` (fire-and-forget) whose failure path leaves a half-written record or a misleading UI — verify the failure path, don't just the happy path.
- About to ask the user "建 PR 吗? / 可以提 PR 了" for a high-risk change when only the standard reviewer + red-team ran — the multi-dimensional impact-radius review (4b-full, front+back when impacted) is the GATE before suggesting a PR; run it and show the consolidated table first.
- About to verify a frontend/UI change in a HEADLESS browser (or letting a subagent drive headless) — the user wants to SEE it; re-run with `agent-browser --headed`. And if a UI fix "doesn't work" on first try, suspect a stale `next dev` (HMR) before suspecting the code — restart the dev server and re-test.
- An issue-driven branch contains fixes for a second tracker issue because it was "nearby" or "overlapped" — split it or ask first. Traceability beats opportunistic bundling.

All of these mean: run the staged verify — **smoke → subagent (normal + red-team) → full** — and paste the raw artifacts. Letter == spirit, **both directions**: "I followed the spirit" is no exemption, AND technically satisfying the letter while defeating the purpose (a self-review labeled "subagent", a retyped/trimmed "raw" response, an unbound placeholder command) is equally a violation.
