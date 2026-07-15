# 实时成本卡模板

版本: v2.7.0

```text
成本状态：
- 本次估算：{estimated_cost} {currency}（{cost_status}）
- 模型路由：{tier}（L0/L1/L2/L3）
- 计费方法：{method}（estimated | measured | modeled）
- 预算上限：{cost_limit}
- 基线成本：{baseline_cost_usd} {currency}
- 相比基线节约：{estimated_savings} {currency} / {estimated_savings_rate_pct}%
- 本周累计：{cumulative_weekly_cost_usd} {currency}
- 主要节约来源：{savings_source}
- 是否值得继续：{continue_or_stop}
- 说明：{note}
```

## 字段说明

| 字段 | 含义 |
|---|---|
| `estimated_cost` | 当前任务或当前步骤的估算成本 |
| `currency` | 币种，默认 USD |
| `cost_status` | `estimate`、`exact`、`unknown`、`over_limit` |
| `tier` | 模型路由等级：`L0`（零模型）、`L1`（轻量/Flash）、`L2`（标准/主力）、`L3`（深度/Pro） |
| `method` | 计费方法：`estimated`（预估）、`measured`（API 实测）、`modeled`（重建/反事实推算） |
| `cost_limit` | 预算上限；未设置时写 `未设置` |
| `baseline_cost_usd` | 参考 `rules/cost-baselines.yaml` 中该 workflow 的基线成本 |
| `estimated_savings` | 相比基线节约金额 |
| `estimated_savings_rate_pct` | 相比基线节约比例 |
| `cumulative_weekly_cost_usd` | 本周累计总成本（所有 workflow 加总） |
| `savings_source` | `cache_hit`、`context_reduction`、`tool_avoidance`、`template_reuse`、`workflow_routing`、`model_routing`、`conact_folding`、`human_time_saved`、`unknown` |
| `continue_or_stop` | `继续`、`停止`、`需要确认` |
| `note` | 成本口径、估算限制或下一步说明 |

## method 三态说明

| method | 含义 | 使用场景 |
|--------|------|----------|
| `estimated` | 基于典型输入/输出 token 估算 | 无法获取 API usage 时（如本地会话） |
| `measured` | 从 API response usage 字段直接读取 | 通过 API 调用且有 usage 返回 |
| `modeled` | 通过反事实推算（如"如果不用工具 X 会省多少"） | Cage counterfactual matrix 场景 |

## transformation 规则

- `estimated` → `measured`：当累计跑满 `calibrate_after_runs` 次且每次均有 API usage 数据时升级
- `measured` → `estimated`：当超过 30 天未重新校准时降级
- `modeled` 仅用于策略探索和 what-if 分析，不用于正式记账

## 使用规则

- 非简单任务必须输出成本卡。
- 任何 workflow 完成后（非 trivial）必须输出成本卡。
- 执行高成本工具、长文件摘要、跨 Agent 分派前，先输出成本卡或成本预估。
- 超过预算上限时，`continue_or_stop` 必须为 `需要确认` 或 `停止`。
- 成本超基线 2x 时（`estimated_cost > baseline_cost_usd × 2.0`），必须阻断并等待用户确认。
- 没有精确计费时，不得省略成本卡；应将 `cost_status` 标为 `estimate` 或 `unknown`。
- `tier` 字段必须填写，引用 `rules/model-routing-rules.yaml` 中的路由决策。
- `baseline_cost_usd` 字段必须填写，引用 `rules/cost-baselines.yaml` 中的基线值。
