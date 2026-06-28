# work.ws — 工作状态总索引（公开示例模板）
# 本文件为去敏后的示例。真实使用时由 Agent 根据你的实际场景填充。
# Agent 每次执行任务前必须读取本文件。

workspace:
  id: example_ops_workspace
  name: 示例运营工作台
  owner: current_user
  mode: personal                       # personal | team | enterprise
  root: "<你的工作目录绝对路径>"
  created: YYYY-MM-DD
  updated: YYYY-MM-DD

status:
  overall: active                      # active | paused | archived
  health: green                        # green | yellow | red
  last_patrol: null
  last_report: null

current_focus:
  primary_scenario: ad_ops
  active_projects:
    - 千里马计划 MVP Phase 1
  pending_decisions: []                # 示例："5 词待调价确认"
  attention_required: []               # 示例："某 SKU 库存偏低"

# 以下为示例场景，结构真实、数据为占位。请按自己的实际业务替换。
scenarios:
  - id: ad_ops
    name: 广告运营
    priority: high
    status: active
    frequency: daily
    core_metrics: [spend, sales, orders, acos, cpc, cvr, tacos]
    workflows: [daily_ad_report, bid_suggestion_review]
    data_sources: [lark_ads_daily, lingsing_ads]
    risk_level: medium

  - id: sales_tracking
    name: 销量台账
    priority: high
    status: active
    frequency: daily
    core_metrics: [units_ordered, sales, sessions, conversion_rate]
    workflows: [sales_ledger]
    data_sources: [lingsing_product, lark_asin_sales]
    risk_level: low

  - id: keyword_tracking
    name: 关键词排名追踪
    priority: high
    status: active
    frequency: twice_daily
    core_metrics: [rank_position, rank_change, spr]
    keywords: ["<示例关键词 1>", "<示例关键词 2>"]
    workflows: [keyword_rank_scan]
    data_sources: [sorftime_mcp, pangolinfo_mcp]
    risk_level: medium

  - id: inventory_monitor
    name: 库存预警
    priority: medium
    status: active
    frequency: daily
    core_metrics: [inventory_on_hand, days_remaining, inbound_qty]
    workflows: [inventory_alert]
    data_sources: [lingsing_product, lark_product_list]
    cross_scenario_triggers:
      - when: inventory_days < 14
        notify: ad_ops
        action: lower_ad_aggressiveness
    risk_level: medium

  - id: profit_review
    name: 利润复盘
    priority: medium
    status: active
    frequency: weekly
    core_metrics: [net_sales, gross_margin, tacos, net_profit_rate]
    workflows: [profit_review]
    data_sources: [lark_ads_daily, lark_asin_sales, lark_product_list]
    risk_level: low

  - id: product_selection
    name: 选品分析
    priority: low
    status: paused
    frequency: on_demand
    workflows: [product_selection_analysis]
    data_sources: [sorftime_mcp, pangolinfo_mcp]
    risk_level: low

# 产品矩阵：示例占位。真实 ASIN/SKU/价格/库存/财务请勿提交到公开仓库，
# 放入 .qianlima/secrets.local.yaml（已被 .gitignore 忽略）。
products:
  active:
    - {asin: "<ASIN>", sku: "<SKU>", name: "<产品名>", price: 0.00, margin: 0.0, inventory: 0, stage: growth}
  clearance: []

annual_targets:
  note: "财务目标属敏感数据，请放入 secrets.local.yaml，不要提交公开仓库"

harness_evolution:
  inspiration: agentic-Harness-engineering
  adapted_concepts:
    - component_observability
    - experience_observability
    - decision_observability
    - evaluate_analyze_improve_loop
  local_files:
    - observability.yaml
    - evaluation-tasks.yaml
    - improvement-loop.yaml
