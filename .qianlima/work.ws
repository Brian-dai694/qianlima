# work.ws - Qianlima workspace state index
# Public template version. Replace placeholders before real use.

workspace:
  id: qianlima_public_template
  name: Qianlima Public Template Workspace
  owner: example_user
  mode: template
  root: "."
  created: 2026-06-23
  updated: 2026-06-24

status:
  overall: template
  health: green
  last_patrol: null
  last_report: null
  last_trial_run: null
  context_policy: enabled

current_focus:
  primary_scenario: ad_ops
  active_event: example_campaign
  active_projects:
    - Qianlima MVP template
  pending_decisions:
    - Replace sample data with your own approved data sources.
  attention_required:
    - Do not commit real customer, product, token, cost, or account data.

scenarios:
  - id: ad_ops
    name: Ad Operations
    priority: high
    status: template
    frequency: daily
    core_metrics: [spend, sales, orders, acos, cpc, cvr, tacos]
    workflows: [daily_ad_report, bid_suggestion_review]
    data_sources: [sample_ads_daily]
    risk_level: medium

  - id: sales_tracking
    name: Sales Tracking
    priority: high
    status: template
    frequency: daily
    core_metrics: [units_ordered, sales, sessions, conversion_rate]
    workflows: [sales_ledger]
    data_sources: [sample_sales_daily]
    risk_level: low

  - id: keyword_tracking
    name: Keyword Tracking
    priority: medium
    status: template
    frequency: on_demand
    core_metrics: [rank_position, rank_change, search_volume]
    keywords: [sample keyword 1, sample keyword 2]
    workflows: [keyword_rank_scan]
    data_sources: [sample_keyword_source]
    risk_level: medium

  - id: inventory_monitor
    name: Inventory Monitor
    priority: medium
    status: template
    frequency: daily
    core_metrics: [inventory_on_hand, days_remaining, inbound_qty]
    workflows: [inventory_alert]
    data_sources: [sample_product_list]
    risk_level: medium

  - id: profit_review
    name: Profit Review
    priority: medium
    status: template
    frequency: weekly
    core_metrics: [net_sales, gross_margin, tacos, net_profit_rate]
    workflows: [profit_review]
    data_sources: [sample_ads_daily, sample_sales_daily, sample_product_list]
    risk_level: low

  - id: product_selection
    name: Product Discovery
    priority: low
    status: template
    frequency: on_demand
    workflows: [product_selection_analysis]
    data_sources: [sample_market_source]
    risk_level: low

  - id: knowledge_digest
    name: Knowledge Digest
    priority: low
    status: template
    frequency: on_demand
    workflows: [knowledge_digest]
    data_sources: [manual_input, inbox_docs, urls, meeting_notes]
    risk_level: low

products:
  active:
    - asin: B0EXAMPLE01
      sku: SKU-EXAMPLE-001
      name: Example Product A
      price: 29.99
      margin: 35.0
      inventory: 100
      stage: template
    - asin: B0EXAMPLE02
      sku: SKU-EXAMPLE-002
      name: Example Product B
      price: 39.99
      margin: 32.0
      inventory: 80
      stage: template
  clearance: []

annual_targets:
  net_sales: 0
  net_profit_rate: 0
  breakeven: 0
  ytd_actual: 0
  ad_budget_monthly: 0
  knowledge_digest_mode: enabled

harness_evolution:
  inspiration: agentic-Harness-engineering
  adapted_concepts:
    - component_observability
    - experience_observability
    - decision_observability
    - evaluate_analyze_improve_loop
    - context_compression
  local_files:
    - observability.yaml
    - evaluation-tasks.yaml
    - improvement-loop.yaml
    - context-policy.yaml

context_governance:
  policy_file: context-policy.yaml
  summary_folder: context-summaries
  default_total_window_tokens: 128000
  usable_context_ratio: 0.70
  safety_reserve_ratio: 0.30
  warning_threshold_ratio: 0.60
  stop_threshold_ratio: 0.85
  direct_read_max_file_size_kb: 20
  default_behavior: summarize_large_files_before_use

model_governance:
  adapter_file: model-adapters.yaml
  default_provider_profile: auto_detect_or_manual
  preferred_low_cost_model: deepseek-v4-flash
  preferred_reasoning_model: deepseek-v4-pro
  fallback_policy: conservative_context_budget

usage_governance:
  ledger_folder: usage-ledger
  track_per_task: true
  track_per_model_call: true
  require_cost_summary_in_report: true

startup_rules:
  must_generate_workspace_index: true
  startup_script: start-qianlima.ps1
  first_read_file: .qianlima/WORKSPACE_INDEX.md
  do_not_load_full_workspace: true
