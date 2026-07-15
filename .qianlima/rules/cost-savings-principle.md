# Cost Savings Principle

Version: v2.7.0
Date: 2026-07-11
Changes:
  - 新增 P0 强制记账规则：任何 workflow 完成后必须写入 usage-ledger，否则 verification gate 不通过
  - 新增节约来源 model_routing：用低 tier 模型代替高 tier 模型完成同类任务
  - 新增 stop condition：单次成本超基线 2x → 阻断并提示用户
  - 新增「成本聚合仪表盘」checklist item
  - 新增引用 rules/cost-baselines.yaml 和 rules/model-routing-rules.yaml

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
- 本次估算：$__（{cost_status}）
- 模型路由：{tier}（L0/L1/L2/L3）
- 预算上限：$__ / 未设置
- 相比基线节约：$__ / __%
- 本周累计：$__
- 主要节约来源：缓存命中 / 少读文件 / 摘要压缩 / 跳过无效工具 / 复用模板 / 模型路由 / 人工时间减少
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

### 🔴 P0 强制规则（v2.7.0 新增）

| 规则 | 说明 |
|------|------|
| **P0-强制记账** | 任何非 trivial workflow 完成后，必须在 `usage-ledger/` 写入一条记录，否则该 workflow 的 verification gate 不通过 |
| **基线必填** | usage-ledger 记录中必须填写 `baseline_cost_usd`（引用 `rules/cost-baselines.yaml`）和 `tier`（引用 `rules/model-routing-rules.yaml`） |
| **超基线阻断** | 单次运行 `estimated_cost > baseline_cost_usd × 2.0` → 阻断并提示用户确认是否继续 |
| **成本聚合** | 每周/每月用 `scripts/new-cost-aggregation.ps1` 跑一次成本聚合仪表盘，输出到 `reports/cost-aggregation-{week|month}.md` |

## Savings Sources

- `cache_hit`: cached prompt or stable prefix reduced model cost.
- `context_reduction`: fewer files or lower compression level reduced tokens.
- `tool_avoidance`: unnecessary browser/API/tool calls were skipped.
- `template_reuse`: existing templates reduced generation work.
- `workflow_routing`: natural language router avoided wrong workflow attempts.
- `model_routing`: task matched to lower-tier model (e.g. L1 flash instead of L2 standard) for same outcome.
- `conact_folding`: long conversation compressed via ConAct memory folding, reducing context tokens.
- `human_time_saved`: output reduced manual checking, copying, or reconciliation.

## Stop Conditions

Ask the user before continuing when:

- Estimated cost exceeds the user-provided limit.
- Estimated cost exceeds the baseline by 2x (trigger: `cost > baseline × 2.0`, see `rules/cost-baselines.yaml` anomaly_thresholds).
- Required data is missing and more paid calls are needed.
- The expected business value is unclear.
- Consecutive 3 runs cost > baseline × 1.5 without quality improvement.

## Cost Aggregation Dashboard

Every week (or on user request), generate a cost aggregation report using `scripts/new-cost-aggregation.ps1`:

- Scan all records in `usage-ledger/`
- Output: 本周累计 / 本月累计 / 各 workflow 成本占比 / 相比基线节约总额 / 成本趋势（最近 30 天）
- Output to: `reports/cost-aggregation-{YYYY-MM-DD}.md`
- Format: Markdown table + 简要分析

## Output Rule

Final answers should include cost and savings status unless the task is trivial or no model/tool usage was material.
