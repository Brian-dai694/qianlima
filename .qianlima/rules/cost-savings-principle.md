# Cost Savings Principle

Version: v2.6.3
Date: 2026-07-09

Qianlima treats cost visibility and savings as a first-class product principle. Every workflow should make cost visible early, keep it visible while running, and explain whether the result justified the spend.

## Core Principle

Cost is not an after-run accounting detail. It is part of the runtime state.

The Agent should optimize for:

1. Lower model cost.
2. Lower tool and data extraction cost.
3. Lower user time cost.
4. Lower operational risk cost.
5. Higher decision value per run.

## Required Cost Card

Every meaningful workflow response should include a compact cost card:

```text
成本状态：
- 本次估算：$__
- 预算上限：$__ / 未设置
- 相比基线节约：$__ / __%
- 主要节约来源：缓存命中 / 少读文件 / 摘要压缩 / 跳过无效工具 / 复用模板 / 人工时间减少
- 是否值得继续：继续 / 停止 / 需要确认
```

If exact metering is unavailable, mark the numbers as estimates instead of omitting the card.

Use `.qianlima/templates/realtime-cost-card_template.md` as the canonical display format. Agents and scripts can generate the same format with `.qianlima/scripts/new-cost-card.ps1`.

## Runtime Rules

- Show cost before expensive steps when cost can exceed the configured limit.
- Prefer cached context, staged summaries, templates, and targeted reads over full workspace reads.
- Stop or ask for confirmation when estimated cost exceeds the task value or configured limit.
- Record estimated cost, baseline cost, savings amount, savings rate, and cost status in usage ledger.
- Use the canonical realtime cost card template so all agents show the same fields in the same order.
- Do not hide cost uncertainty. Use `unknown` or `estimate` explicitly.

## Savings Sources

- `cache_hit`: cached prompt or stable prefix reduced model cost.
- `context_reduction`: fewer files or lower compression level reduced tokens.
- `tool_avoidance`: unnecessary browser/API/tool calls were skipped.
- `template_reuse`: existing templates reduced generation work.
- `workflow_routing`: natural language router avoided wrong workflow attempts.
- `human_time_saved`: output reduced manual checking, copying, or reconciliation.

## Stop Conditions

Ask the user before continuing when:

- Estimated cost exceeds the user-provided limit.
- Estimated cost exceeds the baseline by 2x.
- Required data is missing and more paid calls are needed.
- The expected business value is unclear.

## Output Rule

Final answers should include cost and savings status unless the task is trivial or no model/tool usage was material.
