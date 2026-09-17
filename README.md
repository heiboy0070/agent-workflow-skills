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

## Auto-Trigger Enforcement for Claude(自动触发强制层)

让 Claude Code 收到 **substantial 的 fix/feature/refactor/migration/建 PR** 任务时**自动**进入上面的工作流,而不必每次手动报 skill 名字。装好 skill 软链后,再加两层强制注入 + 一层去噪。

约定 `CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"`(普通安装即 `~/.claude`;cac 等多环境工具取该环境的 `.claude`)。

**① `UserPromptSubmit` hook** — 合并进 `$CFG/settings.json` 的 `hooks` 对象(**勿整体覆盖已有 hooks**):

```json
"UserPromptSubmit": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "printf '%s' '{\"hookSpecificOutput\":{\"hookEventName\":\"UserPromptSubmit\",\"additionalContext\":\"[工作流门禁] 本请求若属 substantial 的 fix/feature/refactor/migration 或建 PR:动代码/git 前先 classify,再用 Skill 工具调起对应工作流——单仓改动用 rigorous-delivery,多仓特性用 rigorous-feature-delivery,高风险(鉴权/并发/支付/状态机/外部集成)先 pre-mortem-design,建 PR 用 creating-pull-requests。功能验证只认真实 API 证据(read-after-write),单测/读代码/tsc 都不算功能验证。轻量问答可忽略本条。\"}}'"
      }
    ]
  }
]
```

校验:`jq -e '.hooks.UserPromptSubmit[-1].hooks[0].command' "$CFG/settings.json"` 应打印命令;
`CMD=$(jq -r '.hooks.UserPromptSubmit[-1].hooks[0].command' "$CFG/settings.json"); echo '{}' | bash -c "$CMD" | jq -r '.hookSpecificOutput.additionalContext'` 应打印门禁文本。

**② 全局 `CLAUDE.md`** 靠前加一条最高优先级规则(冗余保险):

```markdown
# ⚠️ 工作流门禁(最高优先级,先于一切默认行为)
substantial 的 fix/feature/refactor/migration/建 PR:动代码或 git 前先 classify,再用 Skill 调起——
单仓 `rigorous-delivery`;多仓特性 `rigorous-feature-delivery`;高风险(鉴权/并发/支付/状态机/外部集成)先 `pre-mortem-design`;
建 PR `creating-pull-requests`;写对接文档 `writing-integration-docs`。
功能验证只认真实 API 证据(read-after-write),单测/读代码/tsc 都不算。主动调 skill,勿等用户报名字。
```

**③(建议)停用会抢锚点的插件** —— 某些插件(如 superpowers)在 SessionStart 硬注入大段框架,会把项目工作流挤出视野:

```bash
claude plugin disable superpowers@claude-plugins-official   # 确认后其它插件仍 enabled
```

> hook / `CLAUDE.md` 改动在**新会话**或打开一次 `/hooks` 菜单后生效(settings 监听器只监听会话启动时已有 settings 的目录)。

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
