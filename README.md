# Agent Workflow Skills

Reusable workflow skills for AI coding agents.

This repository is the canonical source for a small set of delivery, verification, and planning skills that can be used from both Codex and Claude-style local skill directories.

## Included Skills

| Skill | Purpose |
| --- | --- |
| `rigorous-feature-delivery` | Multi-repository feature delivery workflow with planning, SQL review files, staged verification, documentation, review/red-team steps, and Chinese commit messages. |
| `rigorous-delivery` | Strict implementation and verification workflow requiring real API evidence, headed UI verification when applicable, and current-agent review/red-team checks. |
| `pre-mortem-design` | Pre-implementation risk analysis for high-risk changes such as authentication, concurrency, durable data mutation, state machines, payments, and external integrations. |
| `creating-pull-requests` | Pull request creation workflow requiring user-specified base branches, pre-creation PR body confirmation, clean diffs, and evidence-based verification. |
| `writing-integration-docs` | Integration-facing API doc workflow: read the real implementation, scope to integration-only, full request/response examples, real error cases (JSON vs SSE boundary), fix doc/code drift, publish to Feishu. |

## Repository Layout

```text
skills/
  rigorous-feature-delivery/
    SKILL.md
    agents/openai.yaml
  rigorous-delivery/
    SKILL.md
  pre-mortem-design/
    SKILL.md
  creating-pull-requests/
    SKILL.md
  writing-integration-docs/
    SKILL.md
```

Each skill directory is intentionally self-contained. The required entry point is `SKILL.md`; optional resources such as `agents/`, `scripts/`, `references/`, or `assets/` may be added only when they directly support the skill.

## Installation

Clone the repository:

```bash
git clone git@github.com:heiboy0070/agent-workflow-skills.git
cd agent-workflow-skills
```

Create symlinks from your local agent skill directories to the skill folders in this repository.

For Codex:

```bash
mkdir -p ~/.codex/skills
ln -sfn "$PWD/skills/rigorous-feature-delivery" ~/.codex/skills/rigorous-feature-delivery
ln -sfn "$PWD/skills/rigorous-delivery" ~/.codex/skills/rigorous-delivery
ln -sfn "$PWD/skills/pre-mortem-design" ~/.codex/skills/pre-mortem-design
ln -sfn "$PWD/skills/creating-pull-requests" ~/.codex/skills/creating-pull-requests
ln -sfn "$PWD/skills/writing-integration-docs" ~/.codex/skills/writing-integration-docs
```

For Claude:

```bash
mkdir -p ~/.claude/skills
ln -sfn "$PWD/skills/rigorous-feature-delivery" ~/.claude/skills/rigorous-feature-delivery
ln -sfn "$PWD/skills/rigorous-delivery" ~/.claude/skills/rigorous-delivery
ln -sfn "$PWD/skills/pre-mortem-design" ~/.claude/skills/pre-mortem-design
ln -sfn "$PWD/skills/creating-pull-requests" ~/.claude/skills/creating-pull-requests
ln -sfn "$PWD/skills/writing-integration-docs" ~/.claude/skills/writing-integration-docs
```

After installation, update skill contents in this repository. The local agent directories should remain symlinks.

## Token-Efficient Defaults

The delivery skills keep one agent responsible for planning, implementation, review, red-team, and verification. They do not automatically create subagents; delegation happens only when the user explicitly requests it for the current task.

Quality gates remain risk-tiered: high-risk changes still receive separate normal and adversarial passes plus a multi-dimensional impact review, but those checks run sequentially and reuse one evidence ledger. Narrow fixes rerun only affected checks, and chat reports compact reproducible evidence instead of duplicating full successful test logs.

## Validation

Validate each skill after editing:

```bash
QUICK_VALIDATE="${QUICK_VALIDATE:-$HOME/.codex/skills/.system/skill-creator/scripts/quick_validate.py}"

python3 "$QUICK_VALIDATE" skills/rigorous-feature-delivery
python3 "$QUICK_VALIDATE" skills/rigorous-delivery
python3 "$QUICK_VALIDATE" skills/pre-mortem-design
python3 "$QUICK_VALIDATE" skills/creating-pull-requests
python3 "$QUICK_VALIDATE" skills/writing-integration-docs
```

At minimum, validation should confirm:

- `SKILL.md` exists in every skill directory.
- YAML frontmatter is valid.
- `name` and `description` are present.
- Skill directory names match skill names.

## Maintenance Guidelines

- Keep each `SKILL.md` concise and focused on instructions the agent actually needs at runtime.
- Put reusable implementation details in `scripts/`, longer references in `references/`, and output assets in `assets/`.
- Avoid adding README or setup documents inside individual skill directories.
- Prefer small, reviewable changes over broad rewrites.
- Re-run validation after every skill change.

## Contributing

Changes should preserve the repository layout and keep skills portable across local agent environments. For substantial changes, include:

- What workflow problem the change solves.
- Which skill is affected.
- How the skill was validated.
- Any compatibility impact for Codex or Claude users.

## License

No open-source license has been selected yet. Add a `LICENSE` file before publishing this repository publicly.
