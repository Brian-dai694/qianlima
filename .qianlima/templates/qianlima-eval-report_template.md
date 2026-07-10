# QianlimaEval Report

```yaml
workflow_id: {workflow_id}
run_id: {run_id}
date: {date}
source_inspiration: MiniAppBench / MiniAppEval
evaluation_mode: intent_static_dynamic_cost_risk
status: {status}
weighted_score: {weighted_score}
```

## User Goal

{user_goal}

## Evidence Pack

| Item | Path / Value | Status |
|---|---|---|
| Report | `{report_path}` | {report_status} |
| Trace | `{trace_path}` | {trace_status} |
| Usage | `{usage_path}` | {usage_status} |
| Cost | `{estimated_cost}` | {cost_status} |

## Scores

| Dimension | Weight | Score | Notes |
|---|---:|---:|---|
| Intent Alignment | 0.25 | {intent_score} | {intent_notes} |
| Evidence / Static Quality | 0.25 | {static_score} | {static_notes} |
| Dynamic Execution Quality | 0.25 | {dynamic_score} | {dynamic_notes} |
| Cost Savings / Efficiency | 0.15 | {cost_score} | {cost_notes} |
| Risk Control | 0.10 | {risk_score} | {risk_notes} |

## Hard Blocks

{hard_blocks}

## Pending Verification

{pending_verification}

## Next Optimization

{next_optimization}
