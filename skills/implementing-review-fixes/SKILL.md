---
name: implementing-review-fixes
description: Use when implementing findings from a code review, PR review, audit, red-team, or post-implementation inspection, especially for changes that may alter business behavior, billing, availability, compatibility, or user experience.
---

# Implementing Review Fixes

## Core Rule

**Review findings are evidence, not authorization to redefine product behavior.**

Before changing production code, classify every finding:

- `CLEAR_FIX`: the expected behavior is already established, and the fix preserves business flow, public contracts, availability, billing semantics, and user experience.
- `DECISION_REQUIRED`: the behavior is ambiguous, conflicts with an earlier decision, or may change any boundary below.
- `REJECTED`: the finding is technically incorrect or conflicts with an explicit accepted requirement. Record the evidence; do not implement it silently.

## Mandatory User Gate

Stop before implementing a `DECISION_REQUIRED` finding and tell the user first if it may affect:

- who can use a feature, when it is available, or whether a dependency failure blocks it;
- charging, refunds, quota consumption, free allowance, settlement, or recovery;
- API/client compatibility, error semantics, fallback behavior, or rollout behavior;
- visible admin/client workflow, confirmations, defaults, or user-facing latency;
- realtime session lifecycle, reconnects, duplicate commands, or provider-ready timing.

“Reviewer requested it,” “continue fixing,” release pressure, and sunk implementation cost do not resolve these decisions.

Give one concise decision brief:

1. finding and verified current behavior;
2. exact business/user impact;
3. viable options and trade-offs;
4. recommended option and why;
5. the precise decision needed.

Continue only unrelated `CLEAR_FIX` work while waiting. Do not make shared-state changes that pre-decide the blocked item.

## Workflow

1. Reproduce or verify each finding against the current branch. Reject speculative findings with evidence.
2. Recover accepted behavior from requirements, issue discussion, prior user decisions, tests, and deployed compatibility.
3. Classify the finding before editing.
4. For `CLEAR_FIX`, write a failing regression test first, then make the smallest behavior-preserving fix.
5. For `DECISION_REQUIRED`, obtain the user’s decision, record the accepted behavior, then test and implement it.
6. For high-risk billing, concurrency, auth, durable state, or external integration changes, run the pre-mortem workflow before implementation.
7. Re-run focused tests and relevant regression suites. Review the resulting diff against the accepted behavior, not merely the reviewer’s wording.
8. Report implemented, rejected, and still-blocked findings separately.

## Red Flags

- Choosing an arbitrary timeout, threshold, status transition, or confirmation rule.
- Turning fail-open into fail-close, or the reverse, without approval.
- “Fixing” recovery by charging confirmed usage or refunding it differently.
- Changing an admin workflow because it seems safer without explaining the operational cost.
- Treating a passing test as proof when the test encoded the wrong product behavior.

When in doubt, classify as `DECISION_REQUIRED` and ask before changing behavior.
