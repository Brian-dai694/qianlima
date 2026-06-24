# Work Scenario Governance Spec 工作场景治理标准

## 一句话定义

Work Scenario Governance Spec 是千里马计划的治理中枢标准。它规定一个人的工作空间如何被 Agent 理解、一个工作场景如何定义、一个 workflow 如何被登记、执行和验证、权限边界如何画、成本如何记录、多个场景之间如何联动，以及这一切如何面向没有任何技术背景的大众用户。

## 核心定位

工作场景治理不是项目管理工具，也不是工作流引擎。它是 Agent 理解"用户正在做什么、需要什么、哪些能做、哪些不能做"的基础设施。

它负责回答十个问题：

1. 用户当前有哪些工作场景？
2. 每个场景的当前目标、状态和优先级是什么？
3. 每个场景依赖哪些数据源、文件和工具？
4. 哪些流程可以交给 Agent，哪些只能建议？
5. 每个动作的权限边界在哪里？
6. 执行结果如何验证？
7. 成本是否在预算内？
8. 一个场景的变化如何通知另一个场景？
9. 历史经验和用户偏好如何被复用？
10. 如果出错了，用户怎么知道发生了什么？

一句话概括：

**Work Scenario Governance = time + work.ws + scenario + workflow + permission + cost + cross-scenario + verification + trace。**

---

## 基础维度：时间

时间是整个治理系统最底层的维度。调度、日期计算、数据新鲜度判断、事件时间戳、成本归期、归档轮转——一切治理动作都依赖准确的时间。没有时间，workflow 不知道"昨天"是哪一天，数据源不知道是否过期，跨场景事件不知道先后顺序。

### 时间获取

Agent 在任何治理动作之前，必须先获取当前时间。时间来源只有一个：

> **系统本地时间** — 执行 Agent 所在机器的操作系统时钟。

不依赖网络时间、不依赖第三方 API、不依赖用户告知。Agent 通过执行环境直接读取系统时钟，拿到：

```yaml
time:
  timestamp: "2026-06-23T14:30:00+08:00"
  date: "2026-06-23"
  time: "14:30:00"
  timezone: Asia/Shanghai
  weekday: 周二
  week_number: 26
  month: "2026-06"
  year: 2026
  is_dst: false
```

### 时间的使用

| 治理动作 | 依赖的时间 | 说明 |
|------|:---:|------|
| 计算"昨天"日期 | `date - 1d` | 日报默认数据日期 |
| 判断数据是否过期 | `timestamp - data_refresh_time` | 超过预期更新时间 = 过期 |
| workflow 调度 | `time >= scheduled_time` | 定时任务触发 |
| 归档文件命名 | `date` / `week_number` / `month` | 日报用日期，周报用周数，月报用月份 |
| 事件时间戳 | `timestamp` | 跨场景事件的先后顺序 |
| 成本归期 | `month` | 成本台账按月汇总 |
| 周/月/季边界 | `date` 结合日历 | "本周""本月""Q3"等业务时间范围 |
| 时区转换 | `timezone` | 如果数据源时区与本地不同 |

### 时间容错

- 如果系统时间明显错误（如 1970-01-01 或未来 10 年），Agent 必须在执行前提示用户，不能静默使用错误时间。
- 数据源的日期字段可能与本地时间有时区差（如 Amazon US 的 PST），Agent 应标注而非强制对齐。
- Windows 与 Unix 换行/路径差异不应影响时间解析。

### 面向用户的展示

Agent 使用时间时，必须转换为用户可理解的自然语言：

```text
今天是 2026 年 6 月 23 日，周二，上海时间 14:30。
昨天是 6 月 22 日——这是广告日报的默认数据日期。
本周是第 26 周——周报会标注为 2026-W26。
```

而不是只说：

```text
date=2026-06-23
```

---

## 面向大众用户的原则

千里马计划面对的是没有编辑、编程或项目管理基础的大众用户。治理标准必须：

- 用业务语言，不用技术术语
- 用户只需要描述"我想做什么"，Agent 负责填入治理框架
- 治理规则少而实用，不追求一次性完整
- 默认安全：只读、只建议、写入必确认
- 出错时说人话，不说技术错误
- 用户看不到 yaml 和 json — 它们只是 Agent 的内部工作方式
- 用户可以随时用自然语言修改规则

用户可以这样说：

```text
以后广告日报每天早上 9:30 自动生成。
这个数据源只能读，不能改。
库存低于 14 天就提醒我。
调价之前必须问过我。
这个月 AI 费用不能超过 100 美元。
库存不够的时候，广告建议要保守一点。
```

Agent 应该把这些转换成治理配置，而不是要求用户填表。

## 治理架构总览

```text
.qianlima/
  work.ws                          ← 工作状态总索引（用户当前在做什么）
  work-hub.ws                      ← 跨场景通信中枢（场景之间的联动）
  file-registry.yaml               ← 文件注册表（文件在哪里、被谁用）
  data-sources.yaml                ← 数据源注册表（数据从哪来、权限是什么）
  naming-rules.yaml                ← 文件命名规则
  model-adapters.yaml              ← 不同大模型的上下文、输出、缓存和推理策略
  context-policy.yaml              ← 上下文压缩、文件读取上限和安全冗余
  user-preferences.yaml            ← 用户偏好和习惯
  risk-rules.yaml                  ← 高风险动作和确认规则
  workflows/                       ← 工作流定义
    daily_ad_report.wf.yaml
    sales_ledger.wf.yaml
    inventory_monitor.wf.yaml
    profit_review.wf.yaml
  templates/                       ← 固定模板
  rules/                           ← 治理规则
  inbox/                           ← 用户放入的原始文件
  working/                         ← Agent 当前处理中的文件
  reports/                         ← 最终报告
  exports/                         ← 导出的表格、图片、附件
  archive/                         ← 历史归档
  logs/                            ← 执行日志
  usage-ledger/                    ← Token 与成本台账
  context-summaries/               ← 长文件、多文件任务的结构化摘要
  feedback/                        ← 用户反馈和修正规则
```

六层治理模型：

```text
第〇层：时间基础
  系统时钟 → 日期/周数/时区 → 所有治理动作的时间基准

第一层：工作状态
  work.ws / 场景索引 / 当前目标 / 优先级

第二层：数据治理
  数据源 / Schema / 权限 / 脱敏 / 访问日志

第三层：流程治理
  workflow / SOP / 自动化 / 人工确认点 / 失败恢复

第四层：执行治理
  读取状态 → 执行任务 → 验证结果 → 记录成本 → 复盘优化

第五层：多 Agent 治理
  主控 / 数据 / 分析 / 执行 / 审计 / 文档

第六层：跨场景治理
  指标联动 / 经验复用 / 规则共享 / 异常提醒 / 联动任务
```

---

## 1. work.ws — 工作状态总索引

`work.ws` 是 Agent 理解用户工作状态的唯一入口。它不追求完整，只追求"当前真实"。

### 1.1 核心字段

```yaml
workspace:
  id: amazon_ops_personal
  name: 亚马逊运营工作台
  owner: current_user
  mode: personal              # personal | team | enterprise
  created: 2026-06-23
  updated: 2026-06-23

status:
  overall: active             # active | paused | archived
  last_patrol: 2026-06-23T10:00:00+08:00
  last_report: 2026-06-22
  health: green               # green | yellow | red

current_focus:
  primary_scenario: 广告运营
  active_projects:
    - 千里马计划 MVP
  pending_decisions:
    - 5 词紧急调价确认
  attention_required:
    - PD Day1 关键词巡检
    - P80 Plasma 库存仅 17 套

scenarios:
  - id: ad_ops
    name: 广告运营
    priority: high
    status: active
    description: 每日广告消耗监控、ACoS 诊断、竞价建议和广告日报
    core_metrics:
      - spend
      - sales
      - orders
      - acos
      - cpc
      - cvr
    workflows:
      - daily_ad_report
      - bid_suggestion_review
    data_sources:
      - lark_base_ads_us
      - erp_sales_us
    risk_level: medium

  - id: sales_tracking
    name: 销量台账
    priority: high
    status: active
    workflows:
      - sales_ledger
    data_sources:
      - erp_product_sales

  - id: inventory_monitor
    name: 库存预警
    priority: medium
    status: active
    workflows:
      - inventory_alert
    cross_scenario_triggers:
      - when: inventory_below_14_days
        notify: ad_ops
        action: lower_ad_aggressiveness

  - id: profit_review
    name: 利润复盘
    priority: medium
    status: active
    frequency: weekly

  - id: product_selection
    name: 选品分析
    priority: low
    status: paused

  - id: keyword_tracking
    name: 关键词排名追踪
    priority: high
    status: active
    frequency: twice_daily
```

### 1.2 维护原则

- **不是一次性建完**。优先登记高频场景（广告运营、销量台账、关键词追踪），其他场景按需补充。
- **状态必须真实**。如果一个场景两周没跑过，状态应该是 `paused` 而不是 `active`。
- **用户不需要直接编辑**。Agent 根据对话和行为自动更新，用户可以用自然语言修改。
- **每次执行任务前读取**。Agent 应该先知道用户在做什么、关注什么，再决定怎么做。

---

## 2. 工作场景定义标准

### 2.1 什么是工作场景

工作场景是一个用户反复执行、有明确目标、有固定数据源和输出格式的工作单元。

它不是一次性任务（"帮我查一下这个 ASIN 的价格"），而是会重复出现的工作模式（"每天早上看广告消耗"）。

### 2.2 场景登记标准

每个场景至少要登记：

| 字段 | 说明 | 示例 |
|------|------|------|
| `id` | 场景标识 | `ad_ops` |
| `name` | 用户可读的名称 | 广告运营 |
| `priority` | 优先级 | `high` / `medium` / `low` |
| `status` | 当前状态 | `active` / `paused` / `archived` |
| `workflows` | 绑定的工作流 | `daily_ad_report` |
| `data_sources` | 依赖的数据源 | `lark_base_ads_us` |
| `core_metrics` | 核心关注指标 | `spend, sales, acos` |
| `risk_level` | 风险等级 | `low` / `medium` / `high` |

### 2.3 场景生命周期

```text
discovered → defined → active → paused → archived
```

| 状态 | 说明 | 触发条件 |
|------|------|---------|
| `discovered` | Agent 发现用户反复做某件事 | 对话中检测到重复模式 |
| `defined` | 已登记基本信息和数据源 | 用户确认"这是一个固定工作" |
| `active` | 正常运行中 | workflow 按时执行 |
| `paused` | 暂停（淡季、换季、不再需要） | 用户主动暂停或长期未触发 |
| `archived` | 已归档 | 确定不再需要 |

### 2.4 场景发现

Agent 应该主动建议将重复工作登记为场景。触发条件：

- 同一类任务在 7 天内出现 3 次以上
- 用户明确说"每天""每次""以后都"
- 用户手动要求登记

发现后不能自动创建，必须等用户确认。示例输出：

```text
我注意到你最近一周每天都会查看广告消耗和 ACoS，并让我整理成报告。
要不要把"每日广告运营日报"登记为一个固定工作场景？
以后每天早上可以自动生成，不用每次都说一遍。
```

---

## 3. Workflow 定义标准

### 3.1 什么是 Workflow

Workflow 是工作场景的具体执行流程。一个场景可以有多个 workflow（例如广告运营场景下有日报 workflow 和竞价建议 workflow）。

### 3.2 Workflow 标准结构

```yaml
workflow:
  id: daily_ad_report
  name: 每日广告运营日报
  scenario: ad_ops
  status: active
  description: 每天读取昨日广告数据，计算核心指标，识别异常，生成结构化日报

  schedule:
    type: daily
    time: "09:30"
    timezone: Asia/Shanghai
    auto_run: false                  # MVP 阶段不自动运行
    requires_confirmation: true      # 运行前需要确认

  inputs:
    data_sources:
      - source_id: lark_base_ads_us
        role: ad_performance
        required: true
      - source_id: erp_sales_us
        role: total_sales
        required: false
    parameters:
      - name: date
        type: date
        default: yesterday
        description: 数据日期
      - name: marketplace
        type: enum
        default: US
        options: [US, UK, CA]

  execution:
    mode: single                     # single | daily | weekly | monitor | recovery
    steps:
      - order: 1
        agent: data_agent
        action: read_ad_data
        description: 读取昨日广告数据
      - order: 2
        agent: data_agent
        action: read_sales_data
        description: 读取昨日销量数据
      - order: 3
        agent: data_agent
        action: validate_data
        description: 检查数据质量
      - order: 4
        agent: analysis_agent
        action: calculate_metrics
        description: 计算 ACoS/CPC/CTR/CVR/TACoS
      - order: 5
        agent: analysis_agent
        action: apply_diagnostic_rules
        description: 应用 6 条诊断规则
      - order: 6
        agent: execution_agent
        action: generate_report
        description: 生成 Markdown 日报
      - order: 7
        agent: audit_agent
        action: verify_report
        description: 验证指标、来源和风险
      - order: 8
        agent: execution_agent
        action: record_usage
        description: 记录 Token 使用和成本

  diagnostic_rules:
    - id: high_spend_no_order
      condition: spend >= 10 AND orders = 0
      severity: high
      suggestion: 降低竞价或暂停观察
    - id: high_acos
      condition: acos > target_acos * 1.3 AND orders >= 1
      severity: medium
      suggestion: 降低竞价 10%-20%，检查关键词相关性
    - id: excellent_performance
      condition: acos <= target_acos AND orders >= 2 AND cvr > average
      severity: positive
      suggestion: 保留或小幅加预算
    - id: high_click_low_conversion
      condition: clicks >= 15 AND (orders = 0 OR cvr < average * 0.5)
      severity: medium
      suggestion: 检查主图、价格、Review、Coupon、页面转化
    - id: low_impression
      condition: impressions < 100 AND spend < 5
      severity: low
      suggestion: 检查竞价、预算、关键词搜索量
    - id: budget_spike
      condition: spend > avg_7day_spend * 1.5 AND sales < avg_7day_sales * 1.1
      severity: high
      suggestion: 检查预算设置、竞价和异常关键词

  outputs:
    primary:
      format: markdown
      template: templates/广告运营_日报模板.md
      path: reports/{date}_广告运营_日报_{marketplace}_V{version}.md
    auxiliary:
      - format: json
        path: logs/{date}_daily_ad_report_trace.json
      - format: yaml
        path: usage-ledger/{date}_daily_ad_report_usage.yaml

  quality_gates:
    - check: required_fields_exist
      description: 日报必须包含花费、销售额、订单、ACoS
    - check: date_range_correct
      description: 日期必须是目标日期，不能混入其他日期
    - check: total_spend_matches
      description: 日报总花费与原始数据汇总一致
    - check: no_empty_conclusion
      description: 必须至少有一条诊断结论
    - check: source_cited
      description: 必须标明数据来源和日期范围

  permissions:
    allowed:
      - read_data_sources
      - generate_report
      - write_local_file
    requires_confirmation:
      - send_to_lark_group
      - sync_to_lark_sheet
      - overwrite_existing_report
    forbidden:
      - modify_ad_campaign
      - change_bid
      - change_budget
      - delete_source_data

  error_handling:
    on_data_missing:
      action: report_partial
      user_message: "{date} 的广告数据暂时不可用，已用最近可用日期 {fallback_date} 的数据代替"
    on_data_empty:
      action: report_empty
      user_message: "{date} 暂无广告数据，请检查数据是否已更新"
    on_permission_denied:
      action: stop_and_ask
      user_message: "没有权限读取广告数据，请检查数据源授权"
    on_calculation_error:
      action: skip_and_note
      user_message: "部分指标因数据异常（如 sales = 0）无法计算，已标注"

  trace:
    must_log:
      - data_sources_accessed
      - rows_read
      - diagnostic_rules_fired
      - token_usage
      - estimated_cost
      - duration_seconds
```

### 3.3 Workflow 生命周期

```text
draft → validated → active → running → completed | failed → reviewed
```

| 状态 | 说明 |
|------|------|
| `draft` | 刚定义，还没跑过 |
| `validated` | 数据源、权限、模板已检查 |
| `active` | 可以被触发执行 |
| `running` | 正在执行中 |
| `completed` | 成功完成 |
| `failed` | 执行失败 |
| `reviewed` | 用户已查看结果 |

### 3.4 Workflow 模式

| 模式 | 用途 | 触发方式 | 示例 |
|------|------|---------|------|
| `single` | 临时任务，跑一次就停 | 用户主动触发 | "帮我生成昨天的广告日报" |
| `daily` | 每日固定任务 | 定时或用户触发 | 广告日报、销量台账 |
| `weekly` | 每周复盘 | 定时或用户触发 | 利润复盘、选品周报 |
| `monitor` | 持续监控，异常时提醒 | 定时扫描 | 库存预警、花费异常 |
| `recovery` | 补跑或修复 | 用户触发 | 昨天的数据缺失，今天补 |

MVP 默认使用 `single`。等流程稳定后逐步升级到 `daily` 和 `monitor`。

---

## 4. 文件注册表集成

`file-registry.yaml` 管文件。`work.ws` 管场景。它们之间通过 workflow 建立关联。

### 4.1 关联规则

- 每个 workflow 的输出文件必须登记到 `file-registry.yaml`
- 每个 workflow 的输入文件如果是用户上传的，必须登记
- 模板文件必须登记并标记 `can_overwrite: false`
- 报告文件按日期归档，旧版本自动标记 `retention: archive`

### 4.2 跨 workflow 文件共享

当多个 workflow 使用同一个文件时，文件注册表负责记录引用关系：

```yaml
file:
  file_id: ad_data_2026_06_23_us
  path: inbox/2026-06-23_广告数据_原始_US_V1.xlsx
  used_by:
    - daily_ad_report
    - bid_suggestion_review
    - profit_review
```

如果一个文件被多个 workflow 共享，删除或覆盖前必须检查 `used_by` 列表，提示用户确认。

---

## 5. 数据连接器集成

`data-sources.yaml` 管数据。`work.ws` 管场景。两者通过场景和 workflow 建立关联。

### 5.1 关联规则

- 每个场景必须声明依赖的数据源
- 每个 workflow 必须声明输入数据源及其角色（`required` / `optional`）
- 数据源状态变更（`active` → `warning` → `disabled`）必须通知关联的场景
- 数据源的权限变更必须触发关联 workflow 的权限重检

### 5.2 数据源健康检查

执行 workflow 前，Agent 必须检查数据源状态：

1. 数据源是否存在且状态为 `active`
2. 必填字段是否存在
3. 日期范围是否有数据
4. 权限是否足够
5. 数据是否在有效期内（未过期）

检查失败时，workflow 进入 `error_handling` 流程，而不是直接崩溃。

---

## 6. 权限治理标准

### 6.1 权限分层

```text
数据源权限（data-sources.yaml）
  → 场景权限（work.ws）
    → workflow 权限（workflow 定义）
      → 操作权限（单次执行）
```

下层权限不能超越上层。例如数据源设为 `read_only`，workflow 就不能声明 `write` 权限。

### 6.2 默认权限矩阵

| 操作 | 个人版默认 | 说明 |
|------|:---:|------|
| 读取已授权的数据源 | ✅ 允许 | 前提是数据源已登记 |
| 聚合统计 | ✅ 允许 | |
| 生成本地报告 | ✅ 允许 | Markdown / JSON / YAML |
| 写入本地文件 | ✅ 允许 | 仅限于 reports/ 和 logs/ |
| 写回飞书表格 | ⚠️ 需确认 | 每次写入前确认 |
| 同步到飞书群 | ⚠️ 需确认 | 每次发送前确认 |
| 发送邮件 | ⚠️ 需确认 | |
| 修改广告竞价 | 🔴 二次确认 | |
| 修改广告预算 | 🔴 二次确认 | |
| 暂停/启用广告 | 🔴 二次确认 | |
| 删除数据源文件 | 🔴 禁止 | |
| 导出敏感数据 | 🔴 禁止 | |

### 6.3 确认级别

| 级别 | 说明 | 示例 |
|:---:|------|------|
| 🟢 无需确认 | 常规操作，在授权范围内 | 读取数据、生成报告 |
| 🟡 单次确认 | 每次操作前确认一次 | 写飞书、发消息 |
| 🟠 二次确认 | 连续两次确认，中间展示影响范围 | 调竞价、改预算 |
| 🔴 默认禁止 | 除非显式授权，否则不能执行 | 删除数据、导出敏感信息 |

### 6.4 权限变更

用户可以随时用自然语言调整权限：

```text
以后广告日报自动同步到飞书群，不用每次确认。
库存预警可以自动发消息，但调价还是必须问我。
这个数据源以后可以写入，但仅限于库存数量。
```

Agent 更新 `risk-rules.yaml`，并在下次执行时生效。

---

## 7. 成本治理标准

### 7.1 成本台账

每次 workflow 执行后必须记录：

```yaml
usage_record:
  run_id: ad-report-2026-06-23-001
  workflow_id: daily_ad_report
  scenario: ad_ops
  executed_at: "2026-06-23T09:35:00+08:00"
  status: completed

  model_usage:
    model: claude-opus-4-8
    input_tokens: 18000
    output_tokens: 3200
    cached_tokens: 6000
    estimated_cost: 0.58
    currency: USD

  tool_usage:
    - tool: data_connector
      calls: 3
      rows_read: 1240
    - tool: report_writer
      calls: 1
      files_written: 1

  totals:
    input_tokens: 18000
    output_tokens: 3200
    estimated_cost: 0.58
    duration_seconds: 186

  budget:
    limit: 3.0
    used_ratio: 0.193
    status: within_budget
```

### 7.2 预算控制

| 级别 | 阈值 | 动作 |
|:---:|:---:|------|
| 🟢 正常 | < 70% | 正常运行 |
| 🟡 预警 | 70%-90% | 记录预警，继续运行 |
| 🟠 警告 | 90%-100% | 提示用户，询问是否继续 |
| 🔴 超限 | > 100% | 暂停非关键任务，必须用户确认恢复 |

预算作用域：

```yaml
budget:
  monthly_total: 100.0          # 月度总预算
  per_run_limit: 3.0            # 单次运行上限
  per_workflow_daily: 10.0      # 单个 workflow 每日上限
  currency: USD
```

### 7.3 成本展示原则

- 低成本普通任务：只记录，不强调
- 日报/周报类定时任务：在报告末尾展示简短用量
- 高成本任务：执行前提示预计成本
- 超预算任务：暂停并请求确认
- 每月汇总一次 ROI 复盘

示例（日报末尾展示）：

```text
---
📊 本次运行：读取 1,240 行数据 | 模型调用 1 次 | 估算成本 $0.58 | 用时 186 秒
📈 本月累计：运行 23 次 | 累计成本 $13.34 | 月预算 $100 | 占比 13.3%
```

---

## 7A. 上下文治理标准

上下文治理解决一个核心问题：大模型不能无限读取文件，也不能把所有资料一次性塞进上下文。千里马必须在执行前判断文件量、内容量和任务复杂度，自动压缩上下文，并保留安全冗余。

上下文治理必须和 `model-adapters.yaml` 联动。业务 workflow 不直接关心模型厂商，只声明任务类型、风险等级和输出要求；模型适配层负责选择上下文预算、输出预算、缓存策略和推理冗余。

### 7A.1 不绑定厂商最大窗口

不同模型的上下文窗口不同，而且会随版本变化。千里马不把某个模型的最大窗口写死为系统能力，而是使用可配置预算。

默认策略：

```yaml
model_context_budget:
  usable_context_ratio: 0.70
  safety_reserve_ratio: 0.30
  warning_threshold_ratio: 0.60
  stop_threshold_ratio: 0.85
```

含义：

- 最多只规划使用 70% 上下文。
- 至少保留 30% 给推理、工具返回、异常处理和最终输出。
- 到 60% 开始压缩或摘要。
- 到 85% 必须停止继续塞内容，改用摘要、索引或文件引用。

### 7A.1.1 大模型适配层

`model-adapters.yaml` 负责适配不同模型：

| 类型 | 策略 |
|---|---|
| DeepSeek | 优先适配，单独维护 v4 flash/pro profile |
| OpenAI | 从运行配置读取实际模型窗口，不硬编码 |
| Anthropic | 从运行配置读取实际模型窗口，不硬编码 |
| Google / Gemini | 从运行配置读取实际模型窗口，适合资料消化场景 |
| 本地或开源模型 | 必须手动声明窗口大小和输出上限 |

DeepSeek 当前适配原则：

- `deepseek-v4-flash`：优先用于低成本、批量、日报、资料消化。
- `deepseek-v4-pro`：优先用于复杂推理、高价值分析、多文件综合判断。
- 即使模型支持超长上下文，也不把长文件原文全塞进去；仍然使用分阶段摘要。
- 思考模式任务保留更大安全冗余，避免推理和最终输出挤占上下文。
- 利用上下文缓存时，稳定系统指令和稳定摘要尽量放在前缀，减少重复成本。

### 7A.2 文件读取分级

```yaml
direct_read:
  max_file_size_kb: 20
  max_files_per_turn: 5
extract_then_read:
  max_file_size_kb: 200
summarize_first:
  max_file_size_kb: 2048
index_only:
  min_file_size_kb: 2048
```

规则：

- 小文件可以直接读。
- 中等文件只抽取相关章节。
- 长文档先生成结构化摘要。
- 大文件、数据集、日志和归档只保留索引和引用。

### 7A.3 压缩层级

| 层级 | 名称 | 用途 |
|---|---|---|
| L0 | full_context | 小文件完整读取 |
| L1 | relevant_extract | 中等文件抽取相关段落 |
| L2 | structured_summary | 长文档摘要成事实、风险、行动项 |
| L3 | outline_index | 大文件只保留目录、实体、引用 |
| L4 | source_reference_only | 只保留路径和取用说明 |

### 7A.4 自动触发条件

满足任一条件时必须启动压缩：

- 预计上下文超过 warning threshold。
- 本轮需要读取超过 5 个文件。
- 任一文件超过直接读取上限。
- 同一个大文件被重复引用。
- workflow 超过 3 个步骤。
- 用户一次提供多份文档。
- 历史对话已经影响当前任务空间。

### 7A.5 摘要必须保留来源

每份摘要至少包含：

```yaml
file_path: required
source_type: required
why_relevant: required
key_facts: required
source_sections: required
confidence: required
```

安全规则：

- 摘要不能替代原文件。
- 高风险动作前必须回读原文关键段落。
- 如果结论依赖被省略内容，必须标注待验证。
- 敏感字段默认脱敏或只保留聚合结果。

---

## 8. 跨场景通信标准

### 8.1 work-hub.ws

`work-hub.ws` 是跨场景通信的轻量中枢。它不引入消息队列或事件总线，只是记录场景之间的关联和事件。

### 8.2 四类跨场景联动

| 类型 | 说明 | 示例 |
|------|------|------|
| **指标联动** | 一个场景的指标异常，通知另一个场景 | 广告 ACoS 飙升 → 利润复盘收到提醒 |
| **库存联动** | 库存状态变化，影响广告策略 | 库存 < 14 天 → 广告放量建议自动降级 |
| **事件联动** | 一个场景产生关键事件，触发另一个场景任务 | 选品确认新品 → 自动生成上架检查清单 |
| **经验联动** | 一个场景的教训、规则、偏好，另一个场景复用 | 广告场景的 ACoS 阈值 → 利润场景的预警线 |

### 8.3 跨场景事件标准

```yaml
event:
  id: inv_low_p80_2026_06_23
  type: inventory_risk
  severity: high
  timestamp: "2026-06-23T10:00:00+08:00"

  source:
    scenario: inventory_monitor
    workflow: inventory_alert
    trigger: inventory_below_14_days

  target:
    scenarios:
      - ad_ops
      - profit_review
    action_suggestion:
      for_ad_ops: "P80 Plasma 仅剩 17 套。降低该 ASIN 的广告放量优先级，避免断货后广告空跑。"
      for_profit_review: "P80 Plasma 库存不足，本周利润复盘请标注该 SKU 的供应风险。"

  resolution:
    status: pending             # pending | acknowledged | resolved
    acknowledged_by: null
    resolved_at: null
```

### 8.4 联动规则（个人版默认）

| 规则 | 触发条件 | 联动动作 |
|------|---------|---------|
| CROSS-001 | 库存 < 14 天安全线 | 广告场景降低该 ASIN 的放量建议优先级 |
| CROSS-002 | ACoS 单日飙升 > 50% | 利润复盘场景收到异常提醒 |
| CROSS-003 | 关键词排名暴跌 > 10 位 | 广告场景触发竞价复查建议 |
| CROSS-004 | 新品 Listing 上架 | 关键词追踪场景自动添加新 ASIN 词库 |
| CROSS-005 | 清货 SKU 库存归零 | 利润复盘场景标记清货完成 |

---

## 9. 执行治理标准

### 9.1 执行循环

每个 workflow 的执行遵循固定循环：

```text
┌─────────────────────────────────────────┐
│  0. CLOCK：获取系统时间                   │
│     - 读取系统本地时钟                    │
│     - 解析日期/周数/时区                  │
│     - 校验时钟合理性（非 1970/非远未来）    │
│         ↓                                │
│  1. PREFLIGHT：读取状态，检查前置条件      │
│     - 读取 work.ws                       │
│     - 检查数据源状态                      │
│     - 检查权限                            │
│     - 检查预算                            │
│     - 根据系统时间计算日期范围             │
│         ↓                                │
│  2. EXECUTE：执行任务步骤                 │
│     - 读取数据                            │
│     - 清洗校验                            │
│     - 分析计算                            │
│     - 生成结果                            │
│         ↓                                │
│  3. VERIFY：验证结果                      │
│     - 数据质量检查                        │
│     - 指标准确性验证                      │
│     - 风险动作标记                        │
│     - 来源追溯                            │
│         ↓                                │
│  4. RECORD：记录过程                      │
│     - 执行日志                            │
│     - 成本台账                            │
│     - 访问日志                            │
│     - 更新 work.ws                        │
│         ↓                                │
│  5. DELIVER：交付结果                     │
│     - 输出报告                            │
│     - 展示成本                            │
│     - 标注待确认项                        │
│     - 等待用户反馈                        │
│         ↓                                │
│  6. LEARN：学习改进                      │
│     - 用户反馈处理                        │
│     - 规则优化                            │
│     - 偏好更新                            │
└─────────────────────────────────────────┘
```

### 9.2 失败恢复

| 失败类型 | 恢复策略 |
|------|------|
| 数据源不可用 | 降级：使用备用数据源或最近可用数据，报告中标注 |
| 数据为空 | 生成空报告并说明原因，不报错 |
| 部分数据异常 | 跳过异常行，标注"部分数据已排除" |
| 权限不足 | 停止执行，说明需要的权限 |
| 超出预算 | 暂停，请求用户确认是否继续 |
| 计算错误 | 跳过该指标，标注"无法计算" |
| 模型调用失败 | 重试 1 次，失败后降级为纯规则判断 |

### 9.3 用户确认点

以下节点必须暂停等用户确认，不能自动跳过：

1. 执行前：自动运行的 workflow 首次执行（`auto_run: true` 时）
2. 执行中：触发高风险动作（调价、改预算、发外部消息）
3. 执行后：报告包含需要人工决策的建议
4. 异常时：数据质量检查未通过但用户坚持继续
5. 跨场景：一个场景的 action 会影响另一个场景的 workflow

### 9.4 Harness 运行时最低保障

以下是任何 workflow 能够在生产环境中可靠运行必须满足的 7 条硬性要求。新 workflow 从 `draft` 升级到 `active` 前，必须逐条验证通过。

#### 要求 1：工具调用解析与执行

Agent 发出的每一个工具调用，Harness 必须能够正确解析参数、路由到正确的执行器、在真实环境中完成操作，并将结果返回给 Agent。

```yaml
tool_execution:
  # 工具调用生命周期
  parse:
    - 校验参数类型和必填字段
    - 拒绝格式错误或缺少必填参数的调用（不传递给执行器）
  route:
    - 根据 tool_name 匹配注册的执行器
    - 未注册的工具调用 → 返回 "unknown_tool" 错误给 Agent
  execute:
    - 在真实环境（系统调用/API/浏览器/文件系统）中执行
    - 捕获执行器的返回值或异常
  respond:
    - 将结果序列化为 Agent 可读的格式
    - 错误信息包含错误类型、原因、建议动作
```

#### 要求 2：权限校验与超时控制

任何工具调用在执行前必须通过权限检查，在执行中受超时控制。

```yaml
tool_guard:
  # 权限校验（执行前）
  permission_check:
    order: before_execute
    rules:
      - 检查 Agent 角色是否有权调用此工具
      - 检查当前 workflow 的 permissions.allowed/forbidden
      - 检查目标数据源的 access_level
      - 高风险操作检查是否需要用户确认（risk-rules.yaml）
    on_denied: 返回权限拒绝错误，不执行

  # 超时控制（执行中）
  timeout:
    defaults:
      file_read: 10s
      file_write: 15s
      api_call: 30s
      browser_action: 60s
      database_query: 30s
      model_inference: 120s
    on_timeout:
      - 强制终止工具调用
      - 记录超时日志（工具名、已等待时长、超时阈值）
      - 返回 timeout 错误给调用方
      - 不计入重试次数消耗（超时不算工具失败）
```

#### 要求 3：结构化追溯日志

所有外部操作（工具调用、数据读取、文件写入、API 请求）必须记录在统一的结构化日志中。

```yaml
trace_log_entry:
  run_id: "ad-report-2026-06-23-001"
  step: 4                              # 对应 workflow execution.steps[].order
  agent: data_agent
  tool: data_connector
  action: read
  target: lark_base_ads_us
  timestamp: "2026-06-23T09:35:12+08:00"
  duration_ms: 1234
  request:
    fields: [date, campaign_name, spend, sales, orders]
    date_range: {start: "2026-06-22", end: "2026-06-22"}
  response:
    status: success
    rows_returned: 1240
    bytes: 28400
  error: null
  permission_check:
    allowed: true
    level: read_only
  retry_count: 0
```

日志存储位置：`logs/{run_id}_trace.jsonl`（每行一条日志，支持流式追加和逐行解析）。

#### 要求 4：状态连贯不丢失

一轮任务中，对话历史、中间状态、工作记忆必须在所有 Agent 之间连贯传递，不因 Agent 切换而丢失。

```yaml
execution_context:
  run_id: "ad-report-2026-06-23-001"
  workflow_id: daily_ad_report
  started_at: "2026-06-23T09:35:00+08:00"

  # 工作记忆（跨 Agent 共享）
  work_memory:
    work_ws_snapshot:                  # 执行开始时的 work.ws 快照
      primary_scenario: ad_ops
      health: green
    system_time:
      date: "2026-06-23"
      timezone: Asia/Shanghai

  # 中间状态（Agent 间传递的输出）
  intermediate:
    - step: 1
      agent: data_agent
      output:
        status: success
        rows: 1240
        data_ref: "working/{run_id}_ad_data.json"   # 大数据落盘引用
    - step: 2
      agent: analysis_agent
      input_from: [step_1]
      output:
        status: success
        anomalies_found: 3
        metrics_ref: "working/{run_id}_metrics.json"

  # 对话历史（完整）
  conversation:
    turns: 8
    summary: "用户要求生成 2026-06-22 的广告日报..."
    full_log_ref: "logs/{run_id}_conversation.jsonl"
```

关键规则：
- 大数据（>10KB）不放在执行上下文中，写入 `working/` 目录后只传递文件引用
- 任何 Agent 崩溃后，主控 Agent 可以从最后一个成功的 `intermediate` 步骤恢复
- 执行上下文在 workflow 完成前持续更新，完成后归档到 `logs/{run_id}_context.json`

#### 要求 5：单点失败不崩溃

单个工具调用、单个 Agent 或单个数据源的失败不能导致整个 workflow 崩溃。

```yaml
failure_handling:
  # 工具级
  tool_failure:
    retry:
      max_retries: 2
      backoff: exponential              # 1s → 4s → 16s
      retry_on: [timeout, network_error, rate_limit]
      no_retry_on: [permission_denied, invalid_params, data_not_found]
    degrade:
      - 数据源不可用 → 使用备用数据源
      - 模型调用失败 → 降级为纯规则判断
      - API 超时 → 使用缓存数据（标注数据时间）
      - 文件不可读 → 跳过该输入，标注缺失

  # Agent 级
  agent_failure:
    on_crash:
      - 主控 Agent 检测到子 Agent 异常退出
      - 从 execution_context.intermediate 恢复最后成功步骤
      - 重新分配该步骤到同类型 Agent
      - 同一 Agent 连续失败 2 次 → workflow 进入 recovery 模式

  # Workflow 级
  workflow_failure:
    on_unrecoverable:
      - 生成部分报告（能输出多少输出多少）
      - 标注 "部分结果 — 第 N 步失败"
      - 记录完整的失败上下文供后续 recovery 模式使用
```

#### 要求 6：步数与时间硬限制，可安全取消

每个 workflow 必须有明确的步数上限、时间上限和总预算上限，任一超限即终止。用户可随时安全取消。

```yaml
hard_limits:
  # 步数限制
  max_steps:
    default: 20                         # 单次 workflow 最多 20 个工具调用
    per_agent: 10                       # 单个 Agent 最多 10 个工具调用
    on_exceeded: 终止并报告 "超出步数限制 (max: {max}, actual: {actual})"

  # 时间限制
  max_duration:
    default: 600s                       # 单次 workflow 最长 10 分钟
    per_tool: 120s                      # 单个工具调用最长 2 分钟
    on_exceeded:
      - 发送取消信号给所有正在执行的工具
      - 已完成的步骤结果保留
      - 生成部分报告，标注 "超出时间限制"

  # 取消机制
  cancellation:
    triggers:
      - 用户显式取消（"停止""取消""够了"）
      - 步数超限
      - 时间超限
      - 预算超限
      - 权限被拒绝（不可恢复型）
    behavior:
      - 收到取消信号后，不再发起新工具调用
      - 等待当前正在执行的工具完成（最长 5s，超时强制终止）
      - 保留已产生的中间结果
      - 不写入报告文件（除非用户要求保留部分结果）
      - 记录取消原因和时间戳到日志
    safety:
      - 取消操作本身不能被阻塞
      - 取消信号优先级高于所有其他操作
```

#### 要求 7：完整导出过程数据

一次任务完成后，所有过程数据可以被打包导出，支持人工复核和自动化评测。

```yaml
export_bundle:
  # 导出内容
  contents:
    - execution_context: "logs/{run_id}_context.json"
    - trace_log: "logs/{run_id}_trace.jsonl"
    - conversation: "logs/{run_id}_conversation.jsonl"
    - usage_record: "usage-ledger/{run_id}_usage.yaml"
    - intermediate_data: "working/{run_id}_*"
    - final_report: "reports/{date}_广告运营_日报_{marketplace}_V{version}.md"
    - work_ws_snapshot: "work.ws 执行前/后快照"

  # 导出格式
  format:
    type: zip
    naming: "{run_id}_export_{timestamp}.zip"
    path: "exports/"

  # 用途
  evaluation:
    - 人工抽查：解压后按 trace_log 逐步骤对照原始数据和最终报告
    - 自动化评测：解析 trace_log + usage_record 计算准确性、成本、耗时
    - 回归测试：用同一份输入数据重跑，对比输出是否一致

  # 评测维度
  eval_dimensions:
    - id: accuracy
      description: 指标计算是否正确（抽查 10 条 vs 原始数据手动计算）
    - id: completeness
      description: 是否覆盖所有必检项（见 quality_gates）
    - id: actionability
      description: 诊断建议是否具体可执行（非泛泛的"优化广告"）
    - id: cost_efficiency
      description: Token 消耗 vs 数据量 vs 报告价值
    - id: safety
      description: 是否触碰了 forbidden 操作
```

#### 最低保障与现有治理体系的关系

这 7 条运行时保障是执行治理（§9）的底层基础设施。它们不替代 §9.1-§9.3 定义的执行循环、失败恢复和确认点，而是这些机制能够运转的前提。

```text
§9.1 执行循环        ← 依赖要求 1（工具执行）+ 要求 4（状态连贯）
§9.2 失败恢复        ← 依赖要求 5（单点不崩溃）
§9.3 用户确认点      ← 依赖要求 6（可安全取消）
§6 权限治理          ← 依赖要求 2（权限校验 + 超时）
§7 成本治理          ← 依赖要求 6（预算硬限制）
§11 验收             ← 依赖要求 3（追溯日志）+ 要求 7（导出评测）
```

---

## 10. 多 Agent 治理标准

### 10.1 Agent 角色定义

| Agent | 职责 | 可调用工具 | 权限等级 |
|------|------|---------|:---:|
| 主控 Agent | 理解目标、拆分任务、判断权限、汇总结果 | 全部（受权限约束） | 协调者 |
| 数据 Agent | 读取数据源、字段映射、数据质量检查 | data_connector, file_reader | 只读 |
| 分析 Agent | 计算指标、识别异常、应用诊断规则 | data_connector, calculator | 只读 |
| 执行 Agent | 生成报告、创建文档、同步表格 | report_writer, lark_sheets | 可写本地 |
| 审计 Agent | 检查来源、权限、成本、风险和验收 | data_connector, usage_ledger | 只读 |
| 文档 Agent | 更新 SOP、模板、规则和复盘记录 | file_writer | 可写本地 |

### 10.2 Agent 协作协议

不引入 A2A 协议。Agent 之间通过共享 `work.ws` 和 workflow 状态通信。

```text
主控 Agent 读取 work.ws
  → 创建执行上下文（run_id, workflow_id, 日期范围, 权限边界）
  → 数据 Agent 读取数据，输出结构化结果
  → 分析 Agent 消费数据 Agent 的输出，输出诊断结果
  → 执行 Agent 消费分析 Agent 的输出，生成报告
  → 审计 Agent 消费所有上游输出，输出验证报告
  → 主控 Agent 汇总，更新 work.ws，交付用户
```

每个 Agent 的输出都写入执行上下文，不直接对话。

### 10.3 Agent 问责

- 每个 Agent 的输入和输出都记录在 trace log 中
- 如果报告出错，可以追溯到是哪个 Agent 的哪个步骤
- 如果审计 Agent 发现数据 Agent 的输出有问题，标记 `data_quality_issue` 而不是直接修改
- 用户反馈说"这个建议不对"，Agent 应该定位到分析 Agent 的诊断规则

---

## 11. 验收与质量标准

### 11.1 Workflow 验收清单

一个 workflow 从 `draft` 升级到 `active` 前，必须通过：

- [ ] 至少绑定一个真实数据源
- [ ] 数据源已通过质量检查
- [ ] 权限声明与实际一致
- [ ] 输入输出路径有效
- [ ] 错误处理路径完整
- [ ] 至少试跑一次并人工审核结果
- [ ] 成本记录正常工作
- [ ] 诊断规则输出与人工判断一致（抽查 5-10 条）
- [ ] 报告模板包含来源、日期和成本摘要

### 11.2 报告质量标准

每份 Agent 生成的报告必须：

1. **标明来源**：数据从哪来、什么日期范围
2. **区分事实和判断**：哪些是数据事实，哪些是 Agent 建议
3. **标注异常**：哪些指标异常，为什么异常
4. **说明不确定性**：哪些结论是推测的，需要人工验证
5. **列出待确认项**：哪些动作需要用户决定
6. **记录执行信息**：运行时间、数据量、成本

### 11.3 治理健康评分

每月对工作空间做一次治理健康检查：

| 维度 | 检查项 | 权重 |
|------|------|:---:|
| 数据健康 | 数据源是否都在 `active` 状态？是否有过期数据？ | 25% |
| 流程健康 | workflow 成功率？失败原因是否已修复？ | 25% |
| 权限健康 | 是否有权限越界？是否有未授权的数据访问？ | 15% |
| 成本健康 | 是否在预算内？是否有高成本低价值任务？ | 20% |
| 反馈健康 | 用户满意度？建议采纳率？报告修正频率？ | 15% |

---

## 12. 治理配置文件 Schema

以下两个配置文件在 §13 中被标注为"本 spec 定义"，在此补全其标准结构。

### 12.1 user-preferences.yaml

记录用户的输出偏好、确认习惯、通知渠道和风险容忍度。Agent 从对话中学习，通过用户确认后写入。

```yaml
user_preferences:
  updated: "2026-06-23"
  updated_by: user_confirmed

  output:
    preferred_format: markdown        # markdown | excel | lark_doc | lark_sheet
    report_detail: standard           # brief | standard | full
    show_cost_summary: true           # 报告末尾是否展示成本摘要
    language: zh-CN                   # 报告语言
    date_format: YYYY-MM-DD           # 日期格式偏好

  confirmation:
    auto_confirm_readonly: true       # 只读操作不需确认
    auto_sync_lark_group: false       # 同步飞书群是否自动（默认需确认）
    auto_write_lark_sheet: false      # 写飞书表格是否自动（默认需确认）
    bid_adjust_requires_double: true  # 调价是否需要二次确认
    budget_change_requires_double: true

  notification:
    preferred_channel: lark           # lark | email | terminal
    notify_on_completion: true        # workflow 完成后通知
    notify_on_error: true             # 出错时通知
    notify_on_high_cost: true         # 高成本任务通知
    quiet_hours:                      # 免打扰时段
      start: "22:00"
      end: "08:00"
      timezone: Asia/Shanghai

  risk_tolerance:
    auto_apply_suggestions: false     # 是否自动应用 Agent 建议
    max_auto_bid_change_pct: 0        # 允许自动调价的最大幅度（0=不允许）
    min_inventory_days_for_ad: 14     # 库存低于多少天时广告应降级
    max_daily_budget_without_confirm: 50  # 日预算超过此值需确认

  workflow_defaults:
    daily_report_time: "09:30"
    weekly_report_day: monday
    marketplace: US
```

### 12.2 risk-rules.yaml

记录高风险动作的定义、确认级别和例外规则。

```yaml
risk_rules:
  updated: "2026-06-23"

  # 高风险动作定义
  high_risk_actions:
    - action: adjust_bid
      description: 修改广告竞价
      default_level: double_confirm   # single_confirm | double_confirm | forbidden
      requires_impact_preview: true   # 确认前展示影响范围
      max_change_per_day: 3           # 24h 内同一广告组最多调整次数
      max_change_pct: 50              # 单次调价最大幅度（%）

    - action: change_budget
      description: 修改广告预算
      default_level: double_confirm
      requires_impact_preview: true

    - action: pause_campaign
      description: 暂停广告活动
      default_level: double_confirm
      requires_impact_preview: true

    - action: enable_campaign
      description: 启用广告活动
      default_level: single_confirm

    - action: delete_data
      description: 删除数据源文件
      default_level: forbidden
      allow_override: false           # 不允许用户覆盖此限制

    - action: export_sensitive
      description: 导出敏感数据
      default_level: forbidden
      allow_override: false

    - action: send_to_external
      description: 发送消息到外部（飞书群/邮件/API）
      default_level: single_confirm

    - action: write_to_lark_sheet
      description: 写回飞书表格
      default_level: single_confirm

    - action: overwrite_report
      description: 覆盖已有报告
      default_level: single_confirm

  # 预算风险阈值
  budget_risk:
    per_run_limit_usd: 3.0
    daily_limit_usd: 10.0
    monthly_limit_usd: 100.0
    warning_at_pct: 70
    pause_at_pct: 100

  # 数据质量风险
  data_quality_risk:
    max_null_rate_pct: 20             # 空值率超过此值视为数据异常
    max_staleness_hours: 24           # 数据超过此时间视为过期
    min_rows_for_report: 1            # 生成报告的最小数据行数

  # 跨场景风险联动
  cross_scenario_risk:
    - rule_id: CROSS-001
      description: 库存不足时广告降级
      trigger:
        scenario: inventory_monitor
        condition: inventory_days < 14
      action:
        target_scenario: ad_ops
        effect: lower_aggressiveness
        auto_apply: false             # 是否自动执行（false=仅提醒）

    - rule_id: CROSS-002
      description: ACoS 飙升时通知利润复盘
      trigger:
        scenario: ad_ops
        condition: acos > yesterday_acos * 1.5
      action:
        target_scenario: profit_review
        effect: flag_anomaly
        auto_apply: true
```

---

## 13. MVP 落地检查清单

### 13.1 第一阶段：单场景跑通（对应广告日报 MVP）

- [ ] 建立 `work.ws`，登记 `ad_ops` 场景
- [ ] 建立 `file-registry.yaml`，登记广告数据源文件
- [ ] 建立 `data-sources.yaml`，登记广告数据源
- [ ] 定义 `daily_ad_report` workflow（按本 spec 标准结构）
- [ ] 建立 `templates/广告运营_日报模板.md`
- [ ] 试跑一次 → 人工审核 → 修正规则 → 再跑一次
- [ ] 记录首次执行日志和成本
- [ ] 用户确认"报告符合预期"

### 13.2 第二阶段：治理规则启用

- [ ] 启用 W001-W005（基础治理规则）
- [ ] 启用 BUDGET-001（单次任务预算上限）
- [ ] 建立 `user-preferences.yaml`
- [ ] 建立 `risk-rules.yaml`
- [ ] 跑满一周，汇总成本

### 13.3 第三阶段：多 workflow 扩展

- [ ] 登记 `sales_tracking` 场景 + `sales_ledger` workflow
- [ ] 登记 `inventory_monitor` 场景 + `inventory_alert` workflow
- [ ] 建立 `work-hub.ws`
- [ ] 配置跨场景联动规则（库存→广告、广告→利润）
- [ ] 跑满一个月，做 ROI 复盘

### 13.4 MVP 通过标准

1. `work.ws` 可被 Agent 正确读取和更新
2. 至少一个 workflow 从数据源到报告完整跑通
3. 至少 5 条诊断规则输出与人工判断一致
4. 每次执行都有完整的 trace log 和 cost record
5. 用户不需要看原始数据就能判断"今天广告有没有问题"
6. 权限边界清晰：没有发生过未授权的写入或外发
7. 成本可见：用户知道每次运行花了多少钱
8. **7 条运行时最低保障全部通过**（见 §9.4）：
   - [ ] 工具调用正确解析和执行
   - [ ] 权限校验 + 超时控制生效
   - [ ] 结构化追溯日志完整
   - [ ] 状态连贯不丢失
   - [ ] 单点失败不崩溃（至少验证：数据源不可用、模型调用超时）
   - [ ] 步数/时间硬限制可触发，取消功能可用
   - [ ] 可导出完整过程数据包

---

## 14. 和其他治理文件的关系

```text
work.ws                           ← 本 spec 定义
  记录有哪些工作场景、workflow、目标和状态
  这是 Agent 的"工作记忆入口"

work-hub.ws                       ← 本 spec 定义
  记录场景之间的关联和跨场景事件
  这是 Agent 的"跨场景通信中枢"

file-registry.yaml
  记录文件在哪里、被谁使用、生成了什么
  由本 spec 的 §4 定义与 workflow 的关联规则

data-sources.yaml
  记录数据从哪来、权限是什么、字段是什么
  由本 spec 的 §5 定义与场景的关联规则

naming-rules.yaml
  记录文件命名规范
  所有 workflow 的输出必须遵守

user-preferences.yaml             ← 本 spec 定义
  记录用户偏好、输出格式、确认习惯、风险偏好
  Agent 从对话中学习，通过用户确认写入

risk-rules.yaml                   ← 本 spec 定义
  记录高风险动作和确认规则
  每次执行前由审计 Agent 检查

workflows/*.wf.yaml               ← 本 spec 定义
  每个 workflow 的完整定义
  包含输入、步骤、输出、权限、错误处理、成本预算

templates/
  固定模板，workflow 输出的骨架

usage-ledger/
  Token、模型、API 调用和成本记录
  每次执行后自动写入

logs/
  执行日志、访问日志、验证结果
  支持追溯和审计

feedback/
  用户反馈和修正规则
  驱动持续改进
```

---

## 15. 下一步

本 spec 完成后，千里马计划的四个核心标准都已定义：

| # | 标准 | 文件 | 状态 |
|:---:|------|------|:---:|
| 1 | Harness MVP 架构 | `Harness 千里马计划 MVP ...` | ✅ |
| 2 | PWE 治理方案 | `PWE-v2.0个人使用版-治理方案.md` | ✅ |
| 3 | Data Connector Spec | `Data Connector Spec 数据连接器标准.md` | ✅ |
| 4 | Work Scenario Governance Spec | 本文件 | ✅ |

接下来建议进入实施：

1. **初始化 `.qianlima/` 目录结构**
2. **写第一版 `work.ws`**，登记现有 4 个实际高频场景（广告/销量/关键词/库存）
3. **写第一版 `data-sources.yaml`**，登记现有飞书表格和领星导出数据
4. **写第一个 workflow 定义**：`daily_ad_report.wf.yaml`
5. **用今天的真实数据试跑广告日报 MVP**
