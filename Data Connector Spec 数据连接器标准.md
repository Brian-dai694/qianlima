# Data Connector Spec 数据连接器标准

## 一句话定义

Data Connector Spec 是千里马计划的数据接入标准。它规定个人或企业的数据源如何登记、授权、读取、脱敏、校验、被 workflow 调用，并如何记录使用日志和成本。

它的目标不是让大众用户理解数据库或 API，而是让用户能用自然语言把数据交给 Agent，同时让 Agent 安全、稳定、可追溯地使用这些数据。

> **时间依赖**：数据新鲜度检查、过期判断、`refresh.expected_ready_time` 均依赖系统本地时间。时间获取规范见 **Work Scenario Governance Spec · 基础维度：时间**。

## 核心定位

数据连接器是 Agent 和真实工作数据之间的安全中间层。

它负责回答六个问题：

1. 这个数据源是什么？
2. 谁可以使用它？
3. 可以读什么，不能读什么？
4. 可以写入吗，写入前是否需要确认？
5. 这个数据源适用于哪些工作场景和 workflow？
6. 每次访问数据时，如何记录来源、权限、结果和成本？

一句话概括：

**Data Connector = 数据源登记 + 权限控制 + 字段说明 + 安全读取 + 数据校验 + 使用追踪。**

## 面向大众用户的原则

千里马计划面对的是没有编辑、编程或数据管理基础的大众用户，所以数据连接不能设计成纯技术配置。

核心原则：

- 用户说业务含义，Agent 负责登记数据源。
- 用户不需要知道数据库、API、Schema、Token 这些技术细节。
- 每个数据源都要有用户能看懂的名称。
- 每个数据源都要说明用途、范围、更新时间和风险。
- 默认只读，写入必须确认。
- 敏感字段默认隐藏或脱敏。
- 每次读取都要有访问记录。
- 报告必须能追溯到数据来源。
- 连接失败时要说人话，而不是只报技术错误。

用户可以这样说：

```text
这个表以后作为广告日报的数据源。
这个飞书表是库存数据，每天早上更新。
这个 Excel 是今天的销量数据，只用于这次报告。
以后不要读取客户手机号。
这个数据源只能读，不能改。
```

Agent 应该转换成规范的数据源记录，而不是要求用户手动写配置文件。

## 数据源类型

第一版建议支持 8 类数据源。

| 类型 | 示例 | 适合场景 |
|---|---|---|
| `file_table` | Excel、CSV、本地表格 | 日报、台账、临时分析 |
| `lark_sheet` | 飞书电子表格 | 协作数据、运营表格 |
| `lark_base` | 飞书多维表格 | 结构化业务数据 |
| `database` | MySQL、PostgreSQL、SQLite | 企业业务数据库 |
| `api` | ERP、CRM、广告平台 API | 自动同步数据 |
| `document` | Word、PDF、Markdown、飞书文档 | SOP、合同、会议纪要 |
| `calendar_mail` | 日历、邮件 | 个人助理、客户跟进 |
| `manual_input` | 用户临时粘贴或对话输入 | 一次性任务 |

MVP 不需要一次接入所有类型。建议先支持：

1. `file_table`
2. `lark_sheet` 或 `lark_base`
3. `manual_input`

## 数据源生命周期

每个数据源从接入到停用，需要经历固定状态。

```text
discovered -> registered -> validated -> active -> warning -> disabled -> archived
```

| 状态 | 说明 |
|---|---|
| `discovered` | Agent 发现了可能的数据源，但还没登记 |
| `registered` | 已登记基本信息 |
| `validated` | 已检查字段、权限和样例数据 |
| `active` | 可以被 workflow 正常使用 |
| `warning` | 数据缺失、过期、权限异常或质量不稳定 |
| `disabled` | 暂停使用 |
| `archived` | 历史数据源，只保留记录 |

## data-sources.yaml 标准

`data-sources.yaml` 是数据源注册表。它记录所有可被 Agent 使用的数据源。

建议位置：

```text
.qianlima/data-sources.yaml
```

标准结构：

```yaml
data_sources:
  - source_id: lark_base_ads_us
    display_name: US 广告消耗数据
    type: lark_base
    owner: current_user
    workspace: amazon_ops_personal
    status: active
    business_purpose: 用于生成每日广告运营日报和广告异常分析
    scenarios:
      - 广告运营
    workflows:
      - daily_ad_report
      - bid_suggestion_review

    location:
      provider: lark
      app_token: "***"
      table_name: 广告数据
      view_name: 日报视图

    permissions:
      access_level: read_only
      allowed_operations:
        - read
        - aggregate
      forbidden_operations:
        - update
        - delete
        - export_sensitive
      requires_confirmation:
        - share_report
        - write_back

    refresh:
      frequency: daily
      expected_ready_time: "09:30"
      timezone: Asia/Shanghai

    date_range:
      date_field: date
      default_range: yesterday
      max_range_days: 31

    schema:
      schema_id: ad_campaign_daily_v1
      required_fields:
        - date
        - campaign_name
        - ad_group_name
        - spend
        - sales
        - orders
        - clicks
        - impressions

    privacy:
      sensitivity: medium
      sensitive_fields: []
      masking_required: false

    quality:
      min_rows: 1
      required_checks:
        - required_fields_exist
        - date_range_not_empty
        - numeric_fields_valid
        - duplicate_key_check

    output_trace:
      must_cite_source: true
      show_in_report: true
      source_label: 飞书多维表格：广告数据
```

## 字段说明标准

每个数据源必须配套字段说明。字段说明不只是给 Agent 看，也要能让普通用户理解。

字段结构：

```yaml
schema:
  schema_id: ad_campaign_daily_v1
  business_name: 广告活动每日数据
  primary_keys:
    - date
    - campaign_id
    - ad_group_id
    - keyword_or_asin
  fields:
    - name: date
      display_name: 日期
      type: date
      meaning: 数据对应的日期
      required: true
      example: "2026-06-23"

    - name: spend
      display_name: 广告花费
      type: money
      meaning: 当天广告消耗金额
      required: true
      unit: USD
      can_be_negative: false

    - name: acos
      display_name: ACoS
      type: percent
      meaning: 广告花费占广告销售额的比例
      required: false
      formula: spend / sales
      empty_when: sales = 0
```

字段类型建议：

| 类型 | 说明 |
|---|---|
| `text` | 文本 |
| `number` | 普通数字 |
| `money` | 金额 |
| `percent` | 百分比 |
| `date` | 日期 |
| `datetime` | 日期时间 |
| `boolean` | 是/否 |
| `enum` | 固定选项 |
| `id` | ID、编号 |
| `person` | 人员 |
| `url` | 链接 |
| `file` | 文件 |

## 权限标准

所有数据源默认只读。写入、删除、外发、同步到外部系统必须显式确认。

权限等级：

| 权限 | 说明 |
|---|---|
| `read_only` | 只读，允许查询和聚合 |
| `read_write_confirmed` | 可写，但每次写入前必须确认 |
| `write_limited` | 只允许写入指定字段或指定表 |
| `suggest_only` | 只能给建议，不能修改数据 |
| `blocked` | 禁止访问 |

操作类型：

| 操作 | 默认策略 |
|---|---|
| 读取数据 | 允许，前提是数据源已授权 |
| 聚合统计 | 允许 |
| 生成报告 | 允许 |
| 写入本地报告 | 允许 |
| 写回表格 | 需要确认 |
| 发消息到群 | 需要确认 |
| 发邮件 | 需要确认 |
| 修改预算、竞价、库存、订单 | 二次确认 |
| 删除数据 | 默认禁止 |
| 导出敏感数据 | 默认禁止 |

权限配置示例：

```yaml
permissions:
  access_level: suggest_only
  allowed_operations:
    - read
    - aggregate
    - generate_report
  requires_confirmation:
    - send_to_group
    - create_task
    - write_back
  forbidden_operations:
    - delete
    - change_budget
    - change_bid
    - export_sensitive
```

## 隐私与敏感字段

数据连接器必须识别敏感字段，并默认保护。

敏感字段包括：

- 密码
- Token
- API Key
- 身份证号
- 电话
- 邮箱
- 地址
- 银行账户
- 客户联系方式
- 员工薪资
- 合同金额
- 未发布产品计划
- 商业机密字段

脱敏规则：

```yaml
privacy:
  sensitivity: high
  sensitive_fields:
    - customer_phone
    - customer_email
    - contract_amount
  masking_rules:
    customer_phone: keep_last_4
    customer_email: mask_name
    contract_amount: aggregate_only
  allow_raw_access: false
  raw_access_requires_confirmation: true
```

脱敏展示示例：

| 原始数据 | 脱敏后 |
|---|---|
| `13812345678` | `*******5678` |
| `alice@example.com` | `a***@example.com` |
| 合同金额明细 | 只展示汇总金额 |

## 查询与读取标准

Agent 不能随便把整张表读进上下文。数据连接器要先判断读取范围。

读取原则：

- 先聚合，后明细。
- 先读必要字段，不读无关字段。
- 先读指定日期范围，不默认全量读取。
- 明细行数超过上限时，先抽样或生成摘要。
- 涉及敏感字段时，只返回脱敏或聚合结果。

默认限制：

```yaml
query_limits:
  max_rows_per_query: 5000
  max_columns_per_query: 50
  max_date_range_days: 31
  allow_full_table_scan: false
  require_reason_for_large_query: true
```

Agent 请求数据时，应使用业务意图：

```yaml
query_request:
  purpose: 生成 2026-06-23 的 US 广告日报
  source_id: lark_base_ads_us
  date_range:
    start: 2026-06-23
    end: 2026-06-23
  fields:
    - campaign_name
    - ad_group_name
    - spend
    - sales
    - orders
    - clicks
    - impressions
  aggregation:
    group_by:
      - campaign_name
      - ad_group_name
```

## 数据质量检查

每次数据进入 workflow 前，必须做基础检查。

默认检查：

| 检查 | 说明 |
|---|---|
| required_fields_exist | 必填字段存在 |
| date_range_not_empty | 日期范围有数据 |
| numeric_fields_valid | 数字字段可计算 |
| duplicate_key_check | 主键不异常重复 |
| null_rate_check | 空值比例不过高 |
| freshness_check | 数据没有过期 |
| currency_check | 金额币种一致 |
| percent_format_check | 百分比格式一致 |

检查结果示例：

```yaml
quality_result:
  source_id: lark_base_ads_us
  checked_at: "2026-06-23T09:35:00+08:00"
  status: warning
  rows_checked: 1240
  issues:
    - severity: medium
      field: sales
      issue: 18 行销售额为空，已按 0 处理
    - severity: low
      field: acos
      issue: ACoS 字段缺失，将由 spend / sales 计算
```

## 数据源与文件注册表的关系

`data-sources.yaml` 管“数据从哪里来”。  
`file-registry.yaml` 管“文件在哪里、被谁使用、生成了什么”。

两者必须能互相追溯。

示例：

```yaml
data_source:
  source_id: file_ads_2026_06_23_us
  type: file_table
  file_id: ad_data_2026_06_23_us

file_registry:
  file_id: ad_data_2026_06_23_us
  path: inbox/2026-06-23_广告数据_原始_US_V1.xlsx
  linked_data_source: file_ads_2026_06_23_us
```

## Workflow 调用标准

每个 workflow 必须声明需要哪些数据源。

示例：

```yaml
workflow:
  id: daily_ad_report
  name: 每日广告日报
  required_data_sources:
    - source_id: lark_base_ads_us
      role: ad_performance
      required: true
    - source_id: erp_sales_us
      role: total_sales
      required: false
  required_permissions:
    - read
    - aggregate
  forbidden_operations:
    - update
    - delete
    - change_bid
  output:
    report_template: templates/广告运营_日报模板.md
    report_path: reports/{date}_广告运营_日报_{marketplace}_V{version}.md
```

Workflow 开始前，Agent 必须检查：

1. 数据源是否存在。
2. 数据源是否 active。
3. 权限是否足够。
4. 必填字段是否存在。
5. 日期范围是否可用。
6. 数据质量是否达到最低要求。
7. 是否会触发高风险操作。

## 访问日志标准

每次访问数据源都要记录。

```yaml
access_log:
  run_id: ad-report-2026-06-23-001
  workflow_id: daily_ad_report
  source_id: lark_base_ads_us
  user_id: current_user
  purpose: 生成 2026-06-23 的 US 广告日报
  accessed_at: "2026-06-23T09:35:00+08:00"
  operation: read
  fields_read:
    - date
    - campaign_name
    - spend
    - sales
    - orders
  rows_read: 1240
  sensitive_fields_accessed: []
  masking_applied: false
  result_status: success
```

访问日志用途：

- 让用户知道 Agent 读过哪些数据。
- 支持报告来源追溯。
- 支持安全审计。
- 支持成本与价值复盘。
- 支持错误定位。

## 成本记录标准

数据连接器本身也要记录使用成本。成本不只包括模型 Token，还包括 API 调用、读取行数、处理时间和失败重试。

```yaml
usage_record:
  run_id: ad-report-2026-06-23-001
  source_id: lark_base_ads_us
  workflow_id: daily_ad_report
  rows_read: 1240
  api_calls: 3
  retries: 0
  duration_seconds: 12
  model_tokens_used_after_read: 21200
  estimated_connector_cost: 0.0
  estimated_model_cost: 0.58
```

成本治理规则：

- 自动任务必须记录成本。
- 高成本查询要提示用户。
- 重复读取应尽量使用缓存。
- 报告类任务只把必要摘要交给模型。
- 明细数据优先用表格、SQL 或规则处理。

## 错误处理标准

错误信息要面向大众用户，不能只返回技术错误。

| 错误类型 | 用户可读说明 | 建议动作 |
|---|---|---|
| 数据源不存在 | 找不到这个数据源 | 请上传文件或选择已有数据源 |
| 权限不足 | 当前只能查看，不能修改 | 如需写入，请先确认授权 |
| 字段缺失 | 表里缺少必要字段 | 请补充字段或设置字段映射 |
| 数据为空 | 指定日期没有数据 | 请检查日期或数据是否已更新 |
| 数据过期 | 数据不是最新的 | 请更新数据源后重试 |
| 格式错误 | 表格格式无法识别 | 请使用标准模板或让 Agent 整理 |
| 超出预算 | 本次查询预计成本过高 | 请缩小范围或确认继续 |

错误示例：

```yaml
error:
  code: missing_required_field
  user_message: "这个广告数据表缺少“花费 spend”字段，所以暂时不能生成 ACoS 分析。"
  technical_detail: "required field spend not found"
  suggested_fix:
    - "选择包含广告花费的表格"
    - "把现有字段映射为 spend"
    - "先生成不含 ACoS 的简化日报"
```

## 数据连接器登记流程

标准流程：

```text
1. 用户指定文件、表格、数据库或系统
2. Agent 识别数据源类型
3. 生成用户可读的数据源名称
4. 检查字段和样例数据
5. 判断敏感字段
6. 设置默认只读权限
7. 询问是否绑定到某个工作场景
8. 写入 data-sources.yaml
9. 如果是文件，同时写入 file-registry.yaml
10. 运行一次质量检查
11. 输出登记结果
```

面向用户的登记结果示例：

```text
已把这个表登记为“US 广告消耗数据”。

用途：每日广告运营日报
权限：只读
日期字段：date
主要指标：花费、销售额、订单、点击、展示
风险：未发现敏感字段
后续：可以直接说“用今天的广告数据生成日报”
```

## MVP 接入标准

第一版数据连接器必须做到：

1. 能登记一个文件型表格数据源。
2. 能登记一个飞书表格或多维表格数据源。
3. 能记录数据源名称、类型、用途、权限和状态。
4. 能声明必填字段和字段含义。
5. 能检查日期范围、空值、数字格式和必填字段。
6. 能限制读取范围，避免默认全表读取。
7. 能识别敏感字段并默认脱敏。
8. 能把数据源绑定到 workflow。
9. 能记录访问日志。
10. 能把来源写入最终报告。
11. 能记录 Token、API 调用、读取行数和估算成本。
12. 能在失败时给出用户能理解的原因和建议。

## 广告日报数据连接器示例

```yaml
data_sources:
  - source_id: file_ads_us_daily
    display_name: US 广告日报原始数据
    type: file_table
    owner: current_user
    status: active
    business_purpose: 用于生成每日广告运营日报
    scenarios:
      - 广告运营
    workflows:
      - daily_ad_report

    location:
      file_id: ad_data_latest_us
      folder: inbox
      file_pattern: "{date}_广告数据_原始_US_V{version}.xlsx"

    permissions:
      access_level: read_only
      allowed_operations:
        - read
        - aggregate
        - generate_report
      forbidden_operations:
        - update_source_file
        - delete
        - change_bid

    schema:
      schema_id: ad_campaign_daily_v1
      required_fields:
        - date
        - campaign_name
        - ad_group_name
        - spend
        - sales
        - orders
        - clicks
        - impressions
      optional_fields:
        - acos
        - cpc
        - ctr
        - cvr

    query_limits:
      max_rows_per_query: 5000
      max_date_range_days: 31
      allow_full_table_scan: false

    privacy:
      sensitivity: medium
      sensitive_fields: []
      masking_required: false

    quality:
      required_checks:
        - required_fields_exist
        - date_range_not_empty
        - numeric_fields_valid
        - percent_format_check

    output_trace:
      must_cite_source: true
      show_in_report: true
      source_label: 本地上传：US 广告日报原始数据
```

## 和千里马其他文件的关系

```text
work.ws
  记录有哪些工作场景、workflow、目标和状态

data-sources.yaml
  记录数据从哪里来、权限是什么、字段是什么

file-registry.yaml
  记录文件在哪里、被谁使用、生成了什么

workflow-index.yaml
  记录每个 workflow 需要哪些数据源和输出什么

usage-ledger/
  记录 Token、模型、API、读取量和成本

logs/
  记录每次执行、访问、错误和验证结果
```

## 下一步

Data Connector Spec 跑通后，下一份标准建议写：

> Work Scenario Governance Spec 工作场景治理标准

它用于把 `work.ws`、workflow、文件注册表、数据连接器、权限规则、成本台账和跨场景事件统一起来。

