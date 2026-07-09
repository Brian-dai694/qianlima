# 实时成本卡模板

版本: v2.6.3

```text
成本状态：
- 本次估算：{estimated_cost} {currency}（{cost_status}）
- 预算上限：{cost_limit}
- 相比基线节约：{estimated_savings} {currency} / {estimated_savings_rate_pct}%
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
| `cost_limit` | 预算上限；未设置时写 `未设置` |
| `estimated_savings` | 相比基线节约金额 |
| `estimated_savings_rate_pct` | 相比基线节约比例 |
| `savings_source` | `cache_hit`、`context_reduction`、`tool_avoidance`、`template_reuse`、`workflow_routing`、`human_time_saved`、`unknown` |
| `continue_or_stop` | `继续`、`停止`、`需要确认` |
| `note` | 成本口径、估算限制或下一步说明 |

## 使用规则

- 非简单任务必须输出成本卡。
- 执行高成本工具、长文件摘要、跨 Agent 分派前，先输出成本卡或成本预估。
- 超过预算上限时，`continue_or_stop` 必须为 `需要确认` 或 `停止`。
- 没有精确计费时，不得省略成本卡；应将 `cost_status` 标为 `estimate` 或 `unknown`。
