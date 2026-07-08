# meta-scenario-router.md — 场景智能路由器
# 版本: v1.1 | 更新: 2026-07-08
# 来源: 借鉴 addyosmani/agent-skills 的 Progressive Disclosure 设计
#
# 职责: 根据当前活跃场景，只加载相关的 workflow/task-card/rule，
#       不相关的文件不进入 context。替代"全量加载"模式。
#
# 核心理念: "Don't load all 20 skills at once.
#             A meta-skill router activates only what's relevant."

router:
  id: meta_scenario_router
  version: "1.0"
  principle: >
    每次会话启动或场景切换时，先跑路由判断，再按结果精准加载。
    目标：context 占用降低 40-60%，同时保证关键治理文件不遗漏。

  # ── 始终加载（无论场景）──────────────────────────────────
  always_load:
    - reason: "治理基础设施，任何场景都需要"
      files:
        - ".qianlima/risk-rules.yaml"
        - ".qianlima/context-policy.yaml"
        - ".qianlima/work.ws"
        - ".qianlima/naming-rules.yaml"
        - ".qianlima/harness-health-check.yaml"   # 🆕 v1.1: harness 健康自检
        - ".qianlima/loop-engineering.yaml"      # 🆕 v1.2: Loop Engineering 框架
        - ".qianlima/proactivity.yaml"           # 🆕 v2.3: Raven 主动式监控
        - "全局工作台-工作手册.md"
        - "全局复利踩坑日志.md"

  # ── 场景路由规则 ──────────────────────────────────────────
  routes:

    # 🔴 Prime Day / 大促 持续监控模式
    - id: emergency_ad_ops
      match:
        any:
          - "work.ws 中 harness_health == 'red'（基础设施故障）"
          - "用户提到 '紧急' | '崩盘' | '大面积异常'"
        note: "v2.2 更新: health=red 不再来自 PD（已归档），仅来自 harness 基础设施级故障"
      load:
        workflows:
          - "workflows/keyword_rank_scan.yaml"
          - "workflows/daily_ad_report.yaml"
          - "workflows/traffic_anomaly_diagnosis.yaml"
        task_cards:
          - "task-cards/keyword-monitoring.yaml"
          - "task-cards/traffic-anomaly-diagnosis.yaml"
        rules_extra:
          - ".qianlima/data-sources.yaml"
      skip:
        - "task-cards/product-discovery.yaml"
        - "task-cards/listing-optimization.yaml"
        - "task-cards/competitor-comparison.yaml"
        - "task-cards/keyword-demand-lifecycle-timing.yaml"
        - "workflows/keyword_demand_lifecycle_timing.yaml"
        - "workflows/knowledge_digest.yaml"
      note: "PD 期间 context 预算紧张。只保留广告+关键词核心链路。"

    # 🟡 常规广告运营 + 关键词跟踪
    - id: daily_ad_ops
      match:
        any:
          - "work.ws 中 primary_scenario == 'ad_ops' 且 health != 'red'"
          - "用户提到 '日报' | '广告' | '关键词' | '巡检' | '排名'"
      load:
        workflows:
          - "workflows/keyword_rank_scan.yaml"
          - "workflows/daily_ad_report.yaml"
        task_cards:
          - "task-cards/keyword-monitoring.yaml"
        rules_extra:
          - ".qianlima/data-sources.yaml"
      skip:
        - "task-cards/product-discovery.yaml"
      note: "常规模式。竞品对比、Listing 优化按需触发（见 on_demand 路由）。"

    # 🟢 利润复盘
    - id: profit_review
      match:
        any:
          - "work.ws 中 primary_scenario == 'profit_review'"
          - "用户提到 '利润' | '赚钱' | '毛利' | '成本' | '盈亏'"
      load:
        workflows: []
        task_cards:
          - "task-cards/profit-check.yaml"
        rules_extra: []
      skip:
        - "task-cards/keyword-monitoring.yaml"
        - "task-cards/competitor-comparison.yaml"
        - "workflows/keyword_rank_scan.yaml"
      note: "利润测算需要大量假设亮牌。只加载利润相关文件。"

    # 🔵 竞品对比
    - id: competitor_analysis
      match:
        any:
          - "用户提到 '竞品' | '对比' | '对手' | 'benchmark' | 'ARCCAPTAIN'"
      load:
        workflows: []
        task_cards:
          - "task-cards/competitor-comparison.yaml"
        rules_extra:
          - ".qianlima/data-sources.yaml"
      skip:
        - "*"
      note: "竞品对比是独立场景，几乎不需要其他 task-card。"

    # 🟣 选品探索
    - id: product_discovery
      match:
        any:
          - "work.ws 中 primary_scenario == 'product_selection'"
          - "用户提到 '选品' | '新品' | '能不能做' | '机会' | '蓝海'"
      load:
        workflows: []
        task_cards:
          - "task-cards/product-discovery.yaml"
        rules_extra: []
      skip:
        - "*"
      note: "选品是独立探索场景。"

    # 🟠 Listing 优化
    - id: listing_work
      match:
        any:
          - "用户提到 'Listing' | '优化' | '标题' | '五点' | 'A+' | '图片'"
      load:
        workflows: []
        task_cards:
          - "task-cards/listing-optimization.yaml"
        rules_extra: []
      skip:
        - "*"

    # 📚 资料消化
    - id: knowledge_work
      match:
        any:
          - "work.ws 中 primary_scenario == 'knowledge_digest'"
          - "用户提到 '消化' | '总结' | '提炼' | '读书' | '笔记'"
      load:
        workflows:
          - "workflows/knowledge_digest.yaml"
        task_cards:
          - "task-cards/knowledge-digest.yaml"
        rules_extra: []
      skip:
        - "*"

    # 🔀 关键词需求生命周期
    - id: keyword_lifecycle
      match:
        any:
          - "用户提到 '需求生命周期' | '季节趋势' | '搜索趋势' | 'lifecycle'"
      load:
        workflows:
          - "workflows/keyword_demand_lifecycle_timing.yaml"
        task_cards:
          - "task-cards/keyword-demand-lifecycle-timing.yaml"
        rules_extra: []
      skip:
        - "*"

  # ── 默认路由（fallback）───────────────────────────────────
  default:
    description: "当没有场景匹配时，只加载 always_load + work.ws 中 status==active 的 scenarios 对应的最小文件集"
    load:
      workflows: []
      task_cards: []
      rules_extra: []
    action: "从 work.ws 读取 active scenarios，只加载对应 workflow 和 task-card"

  # ── 路由执行流程 ──────────────────────────────────────────
  execution:
    step_1: "读取 work.ws 确认当前 primary_scenario 和 health 状态"
    step_2: "按 routes 顺序匹配第一条符合条件的路由（first-match wins）"
    step_3: "加载 always_load + 匹配路由的 load 列表"
    step_4: "显式跳过匹配路由的 skip 列表中的文件"
    step_5: "🆕 执行 harness 健康自检（按 harness-health-check.yaml 的 execution 流程）"
    step_6: "在响应开头告知用户：当前场景 = X，健康 = G/Y/R，已加载 Y 个文件，跳过了 Z 个文件"
    step_7: "场景切换时（用户提到新的意图关键词），重新执行 step_1-6"
