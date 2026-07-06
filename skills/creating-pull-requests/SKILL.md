---
name: creating-pull-requests
description: Use when asked to open / submit / create a pull request (提交 PR / create PR / open pull request / merge to main|master) — especially from a merged or integration branch into a long-lived branch.
---

# Creating Pull Requests

## Overview
Opening a PR is outward-facing and easy to get wrong on autopilot: assuming the base branch, creating before the user sees the body, and writing vague verification. This skill enforces: **user-specified base, confirm-before-create, evidence-based description.**

违反字面 == 违反精神。下面每条都不是建议,是必须。

## Gate — full review BEFORE you even suggest a PR
Opening a PR is the LAST step, not a verification step. A change reaches "ready to PR" only after a **comprehensive multi-dimensional review** has run (rigorous-delivery **4b-full** panel — security / data-lifecycle / frontend-robustness / integration-regression, each auditing the WHOLE change in parallel, consolidated into one severity-ranked table) AND you've confirmed it's mergeable: **no open P0/P1**, P2/P3 triaged with the user. A standard single reviewer + red-team pass is **NOT** enough to even *prompt* the user to create a PR. If the full review hasn't run, STOP — run it first (covering both frontend AND backend when the change spans both repos); only then tell the user the work is PR-ready. Asking "要不要建 PR? / shall I open a PR?" off the standard pass alone is a violation of this gate.

## Iron rules (never violate)
1. **Base/target branch is USER-SPECIFIED — never assume or default.** It may be `main`, `master`, `develop`, `release/*`, or a parent feature branch. If the user didn't state it, **ASK and wait** — do NOT run `gh pr create` until they answer. "Repo's default is main" is not permission to assume.
2. **Show the full PR body to the user and get explicit confirmation BEFORE creating.** No create-then-show. A terse "提交pr吧" is NOT confirmation of the body — draft it, show it, wait for "ok".
3. **Verification section = concrete evidence, not a summary.** Every line must name three things: **(a) the real test data** — a concrete entity with id/name + the relevant field values ("Emma Wang, child 1, profile route 'Patriots'"), never "a child" / "some pickup" / "the endpoint"; **(b) the exact endpoint or command** hit (real path + real id, a runnable form); **(c) the literal observed result** — status code AND the specific field values you saw. A reviewer must be able to re-run the line from the line alone. Never write "tests pass" / "endpoints verified" / "每个提交都验证过" / "经真实 API 验证" without the per-check artifact — those vague summaries are exactly what gets rejected. Only claim what you actually produced this session (evidence over assertion — see **REQUIRED BACKGROUND:** Use rigorous-delivery).
4. **Pre-PR cleanliness gate.** Before pushing, run `git diff <base>..HEAD --name-only` and confirm it contains ONLY intended files. Catch accidentally-committed scratch/untracked files (the `git add -A` trap — prefer explicit `git add <paths>`), leftover `<<<<<<<` conflict markers, and that build/tests are green.
5. **Don't auto-close issues, and keep issue codes out of the body.** Avoid closing keywords (`Closes`/`Fixes`/`Resolves #123`) — they silently close tracker items on merge. **Also keep issue codes (e.g. `INF-690`, `#123`) OUT of the PR body entirely — describe the issue by its subject/topic, never its tracker id** (user preference: no issue numbers in PR text). The tracker lives in the branch tooling / PR metadata, not the prose.
6. **The enumerated list of known follow-ups / unfixed issues does NOT go in the PR body.** A PR presents *completed, verified* work. Anything the work or a review turned up but did NOT fix — deferred bugs, semantic decisions, latent edges — is surfaced to the **USER in chat**: list each one and ask whether to open a tracker issue; let the user decide. Do not inline that list in a `## 已知限制` / "Known follow-ups" section where it reads as shipping-with-known-defects. **Do NOT carry the tracker code into the PR body either** — not as a closing keyword, not as a bare `Refs INF-690`. Describe the follow-up by its subject to the user in chat; they decide whether to track it. The PR body stays free of issue numbers (Iron rule 5), and the inline enumerated defect list also doesn't belong in it.

## Process
0. **Full-review gate** (see **Gate** above): confirm the change passed the 4b-full multi-dimensional review — frontend AND backend if it spans both — with no open P0/P1, and the consolidated table was already shown to the user. If it hasn't run, STOP and run the full review before touching the PR flow.
1. **Confirm base branch** (Iron rule 1) — ask if not given.
2. **Cleanliness gate** (Iron rule 4): `git diff <base>..HEAD --name-only` only-intended; no markers; `build` + `test` green.
3. **Draft the body** using the template below; verification as named-data → endpoint → seen-result (Iron rule 3).
4. **Surface follow-ups to the user, NOT into the body** (Iron rule 6): if the work / a review found unfixed issues or deferred decisions, list them in chat with a recommendation and ask whether to open issues. Wait for the user's call.
5. **Show body → wait for confirmation** (Iron rule 2).
6. **Push** the branch, then `gh pr create --base <user-specified> --head <branch> --title "..." --body-file <file>`.

## PR body template
```markdown
## 概述           — why/what, one paragraph
## 做了什么 / 完成的功能   — features by area/module (describe by feature, not issue number)
## 关键设计         — notable decisions / trade-offs
## 验证            — per check: 数据(真实 id/名 + 字段值) → 接口/命令(真实路径+id) → 实际结果(状态码 + 看到的字段值)
## 不在本 PR 范围     — genuine scope boundaries only (NOT a list of unfixed bugs — those go to the user, Iron rule 6)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

`## 验证` lines must look like (reproducible, named data → endpoint → seen result):
```
- Emma Wang (child 1, profile route "Patriots") → POST /pending-pickups pickup_route="HACKED" → GET /board 返回 pickup_route="Patriots"（override 被忽略，档案未改）
- 软删 child 11 后 → GET /board?date=2026-06-15 → unassigned:[]（PII 不泄漏，软删前含该孩子）
- 20 个并发 POST /pending-pickups（不同 stop，同 date/child/null-session）→ 全部响应 == 唯一存储行 Stop_01（20/20，修复前 ~19/20 发散）
- go test ./internal/... → ok（service 0.9s, repository 等全 ok）
```
NOT like: "经真实 API 验证 / 每个提交都测过 / endpoints verified"（无数据无结果 = 不合格）。

## Red flags — STOP
- About to suggest "要不要建 PR / shall I open a PR / 可以提 PR 了" when only the standard reviewer + red-team ran (no full multi-dimensional review across front+back) → STOP, run 4b-full first and confirm no open P0/P1.
- About to `gh pr create --base main` without the user naming the base → STOP, ask.
- About to create the PR without having shown the body → STOP, show it first.
- Verification section says "tests pass / verified / 经真实 API 验证" with no command + named data + actual output → STOP, add evidence or state honestly what wasn't run.
- A verification line doesn't name the entity (id/name) AND the endpoint AND the value you saw → STOP, it's not reproducible; rewrite as `数据 → 接口/命令 → 实际结果`.
- About to put a `## 已知限制` / "Known follow-ups" / known-bugs list in the PR body → STOP, those go to the user to triage into issues (Iron rule 6).
- About to write an issue code (`INF-690` / `#123` / `Refs ...`) anywhere in the PR body → STOP, remove it; describe the issue by its subject (Iron rule 5, user preference).
- Used `git add -A` / `git commit -am` near the PR → STOP, check `git diff <base>..HEAD --name-only` for stray files.

## Rationalizations (forbidden)
| Excuse | Reality |
|--------|---------|
| "Repo default is main, just use it" | Base is the user's call; integration/feature branches often target a non-main base. Ask. |
| "'提交pr' means just do it" | It means *make* the PR, not skip showing the body. Confirm first. |
| "Reviewer already tested it, I'll write 'verified'" | Don't claim evidence you didn't produce. State who verified, or paste your own real output. |
| "'经真实 API 验证' / 'verified read-after-write' is enough" | Name the entity (id/name) + the endpoint + the value you saw, per check. A summary that can't be re-run is not evidence. |
| "List the known bugs in the PR so reviewers know" | Follow-ups go to the **user** to triage into issues, not the PR body (Iron rule 6). The PR shows verified, completed work. |
| "A non-closing `Refs INF-690` is harmless context" | User preference: NO issue codes in the PR body. Describe the issue by its subject; keep the tracker id out of the prose entirely. |
| "git add -A is faster" | It commits stray untracked files. Use explicit paths; check the diff before PR. |
