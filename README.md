# Agent Workflow Skills

This repository is the canonical home for personal agent workflow skills.

## Skills

- `rigorous-feature-delivery`: Codex-facing workflow for substantial multi-repo feature delivery, planning, SQL-as-file review, staged verification, documentation, and Chinese commits.
- `rigorous-delivery`: Strict delivery and verification workflow requiring real API evidence, headed UI verification, independent review, and adversarial red-team review.
- `pre-mortem-design`: Pre-planning risk analysis for high-risk changes such as auth, concurrency, durable data mutation, state machines, payments, and external integrations.

## Local Links

The local Codex and Claude skill directories should point to the folders under `skills/`:

- `~/.codex/skills/rigorous-feature-delivery`
- `~/.codex/skills/rigorous-delivery`
- `~/.codex/skills/pre-mortem-design`
- `~/.claude/skills/rigorous-feature-delivery`
- `~/.claude/skills/rigorous-delivery`
- `~/.claude/skills/pre-mortem-design`

Update skill contents in this repository only. The local skill entries are symlinks.
