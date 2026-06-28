# Harness 千里马计划 MVP：数据上下文层与广告运营日报 Agent

## 一句话定义

Harness 千里马计划是一套面向 AI Agent 的高可靠执行与数据上下文系统。它通过连接个人和企业数据源，理解用户角色、业务状态和真实需求，再结合任务规划、工具编排、权限控制和质量验证，让 Agent 从被动问答升级为主动理解、可靠执行和持续优化的智能工作系统。

> **基础依赖**：本系统所有调度、日期计算、数据新鲜度判断均依赖系统本地时间。时间获取规范见 **Work Scenario Governance Spec · 基础维度：时间**。

## 项目定位

千里马计划不是单点功能，而是一套面向个人和企业工作场景的 Agent 执行与治理系统。

它的目标不是单纯让模型“更聪明”，而是让 Agent 在日常工作、运营管理、数据分析、协作沟通和业务决策中更稳定、更可控、更可评估，并且能够基于真实数据更快理解个人或企业的需求。

可以拆成三层：

1. 底座层：工具调用、权限、文件系统、浏览器、API、数据库、日志、状态管理。
2. 能力层：任务拆解、上下文管理、失败恢复、质量检查、长期记忆、需求发现。
3. 应用层：运营分析、飞书协作、广告优化、选品研究、库存预警、利润监控、客户跟进、个人助理等具体工作场景。

## 核心判断

Agent 要真正理解个人或企业需求，不能只靠对话上下文，必须接入真实数据上下文。

原来的 Harness 负责“让 Agent 会执行”。加入数据库和企业/个人数据接口后，它进一步变成：

> 一个能连接真实数据、理解用户状态、发现需求并执行任务的 Agent 操作系统。

也就是说，千里马计划不只是“跑得稳”，还要“知道该往哪里跑”。

## 新版架构

```text
用户
  -> Agent Harness
    -> Task Spec：任务规格化
    -> Data Context Layer：数据上下文层
      -> Connector Registry：连接器注册中心
      -> Permission Guard：权限与隐私保护
      -> Schema Registry：数据结构注册表
      -> Safe Query Executor：安全查询执行器
      -> Data Normalizer：数据清洗与标准化
    -> Planner：计划与编排
    -> Tool Router：工具路由
    -> Execution Memory：执行记忆
    -> Analysis Engine：分析引擎
    -> Report Generator：报告生成器
    -> Verifier：结果验证器
    -> Trace Logger：过程追踪
    -> Usage & Cost Ledger：使用量与成本台账
    -> Budget Guard：预算控制器
  -> 日报 / 建议 / 执行记录
```

## 七层能力

1. 任务理解层：理解用户当前提出的需求。
2. 数据上下文层：连接个人或企业数据，理解用户真实状态。
3. 计划与编排层：根据任务和数据制定执行路径。
4. 工具执行层：调用浏览器、文件、API、数据库、业务系统。
5. 上下文与记忆层：管理短期任务状态和长期偏好。
6. 质量验证层：检查结果是否符合目标。
7. 观测、成本与反馈层：记录过程、失败、成功经验、用户反馈、Token 使用和模型调用成本。

## 个人/企业工作场景治理方案

这一部分参考 PWE 个人版的治理思路，但不按编程项目来设计。千里马计划的核心治理对象不是代码仓库，而是一个人或一个团队的真实工作场景。

它要解决的问题是：

- 我现在有哪些高频工作场景？
- 每个工作场景依赖哪些数据源和工具？
- 哪些流程可以交给 Agent 自动跑？
- 哪些动作只能建议，不能自动执行？
- 哪些结果需要人工确认？
- 哪些任务成本高但价值低？
- 哪些经验可以复用到其他工作流？

一句话概括：

**千里马工作场景治理 = work.ws + data context + workflow + guardrail + usage ledger + feedback loop。**

### 工作场景能力结构

个人或企业工作版保留 6 个核心层次：

```text
第一层：工作状态
work.ws / 场景索引 / 数据源索引 / 当前目标

第二层：数据治理
数据连接器 / Schema / 权限 / 脱敏 / 访问日志

第三层：流程治理
workflow / SOP / 自动化任务 / 人工确认点

第四层：执行循环
读取状态 / 执行任务 / 验证结果 / 记录成本 / 复盘优化

第五层：多 Agent 协作
主控 Agent / 数据 Agent / 执行 Agent / 审计 Agent / 文档 Agent

第六层：跨场景复用
经验复用 / 指标复用 / 规则复用 / 异常提醒 / 联动任务
```

相比开发类治理，工作场景治理暂时不把测试、Commit、代码审查作为主线，而是把数据准确性、流程可控性、权限边界、成本可见性和结果可验证作为主线。

### 工作状态源：work.ws

每个个人或企业工作空间保留一个 `work.ws`，作为 Agent 理解工作状态的核心索引。

它记录：

- 工作场景：广告运营、选品分析、库存预警、利润监控、客户跟进、会议纪要、日报周报等。
- 数据源：飞书表格、多维表格、ERP、CRM、邮箱、日历、本地文件、数据库、API。
- 关键指标：销售额、利润率、库存周转、广告花费、ACoS、TACoS、转化率、回款状态等。
- 工作流：每日广告日报、每周选品复盘、库存预警、客户跟进提醒、会议纪要整理。
- 权限状态：哪些数据可读、哪些动作可写、哪些操作必须确认。
- 执行记录：最近运行时间、成功失败、异常原因、Token 消耗、估算成本。
- 用户偏好：报告格式、常看指标、通知渠道、确认习惯、风险偏好。

示例：

```yaml
workspace:
  name: amazon_ops_personal
  owner: current_user
  mode: personal

scenarios:
  - id: ad_ops
    name: 广告运营
    priority: high
    data_sources: [lark_base_ads, erp_sales_export]
    workflows: [daily_ad_report, bid_suggestion_review]
    core_metrics: [spend, sales, orders, acos, tacos, cvr]
    default_output: markdown_report
    risk_level: medium

permissions:
  default_data_access: read_only
  auto_write_allowed: false
  require_confirmation:
    - send_to_group
    - create_task
    - update_budget
    - adjust_bid

usage:
  monthly_budget_usd: 100
  cost_center: 广告运营
```

个人使用时，不需要一开始就把所有内容建得很完整。优先登记四类信息：

- 高频工作场景
- 核心数据源
- 常用输出格式
- 必须确认的高风险动作

### 大众版文件管理原则

千里马计划面对的是没有任何编辑、编程或文件管理基础的大众用户，所以文件系统必须被设计成“固定、可见、可解释、可恢复”。

核心原则：

- 固定工作文件：每类工作都有固定文件，不让用户猜文件在哪里。
- 固定命名规则：文件名能看出日期、场景、用途和版本。
- 固定存放位置：输入、输出、模板、日志、归档分开放。
- 固定调用关系：每个 workflow 明确读取哪些文件、生成哪些文件、更新哪些索引。
- 用户不用理解技术目录：Agent 可以用自然语言解释“我用了哪些文件”。
- 不覆盖原文件：默认新建版本或写入归档，覆盖必须确认。
- 可追溯：每份报告都能追到来源文件、数据范围和生成记录。

### 标准工作目录

为了让大众用户不迷路，建议每个工作空间都使用固定目录。

```text
.qianlima/
  work.ws                         工作状态总索引
  work-hub.ws                     跨场景索引
  file-registry.yaml              文件注册表
  data-sources.yaml               数据源注册表
  naming-rules.yaml               文件命名规则
  workflows/                      工作流定义
  templates/                      固定模板
  inbox/                          用户放入的原始文件
  working/                        Agent 当前处理中的文件
  reports/                        最终报告
  exports/                        导出的表格、图片、附件
  archive/                        历史归档
  logs/                           执行日志
  usage-ledger/                   Token 与成本台账
  feedback/                       用户反馈和修正规则
```

对用户展示时，不需要暴露这些技术目录。可以转换成更好理解的名称：

| 系统目录 | 用户看到的名称 | 用途 |
|---|---|---|
| `inbox/` | 待处理文件 | 用户上传、拖入或指定的原始文件 |
| `working/` | 正在处理 | Agent 临时整理中的文件 |
| `reports/` | 最终报告 | 可以直接阅读、发送或归档的结果 |
| `templates/` | 固定模板 | 日报、周报、会议纪要、复盘模板 |
| `archive/` | 历史归档 | 旧版本和历史结果 |
| `logs/` | 执行记录 | Agent 做过什么 |
| `usage-ledger/` | 使用成本 | Token、模型调用和费用记录 |

### 固定工作文件

每个工作空间至少保留这些固定文件。

| 文件 | 作用 | 用户是否需要直接编辑 |
|---|---|---|
| `work.ws` | 当前工作状态总索引 | 不建议 |
| `file-registry.yaml` | 记录所有重要文件的位置、用途、来源和调用关系 | 不建议 |
| `data-sources.yaml` | 记录数据源、权限、字段和更新频率 | 不建议 |
| `naming-rules.yaml` | 记录文件命名规则 | 不建议 |
| `workflow-index.yaml` | 记录有哪些固定工作流 | 不建议 |
| `user-preferences.yaml` | 记录用户偏好、输出格式、确认习惯 | 可通过对话修改 |
| `risk-rules.yaml` | 记录高风险动作和确认规则 | 可通过对话修改 |

Agent 可以帮用户维护这些文件。用户只需要用自然语言说：

```text
以后广告日报都放到最终报告里。
这个表以后作为广告数据源。
日报文件名要带日期和站点。
不要覆盖旧版本。
```

### 文件命名规范

文件名要让普通用户一眼看懂。建议统一格式：

```text
日期_场景_用途_范围_版本.扩展名
```

标准示例：

```text
2026-06-23_广告运营_日报_US_V1.md
2026-06-23_销量台账_日报_US_V1.xlsx
2026-06-23_库存预警_异常清单_US_V1.xlsx
2026-W26_利润复盘_周报_US_V1.md
2026-06_使用成本_月报_全部场景_V1.md
```

命名字段说明：

| 字段 | 说明 | 示例 |
|---|---|---|
| 日期 | 日报用 `YYYY-MM-DD`，周报用 `YYYY-W周数`，月报用 `YYYY-MM` | `2026-06-23` |
| 场景 | 工作场景名称 | 广告运营、库存预警、利润复盘 |
| 用途 | 文件用途 | 日报、周报、异常清单、复盘、台账 |
| 范围 | 站点、账号、项目或全部 | US、UK、全部场景 |
| 版本 | 防止覆盖 | V1、V2、Final |

不建议使用：

- `新建文档.md`
- `未命名.xlsx`
- `最终版最终版2.docx`
- `广告数据最新.xlsx`
- `report.md`

### 文件注册表

`file-registry.yaml` 用来解决跨文件调用问题。它记录每个文件是什么、从哪里来、被哪个 workflow 使用、是否可以覆盖。

示例：

```yaml
files:
  - file_id: ad_data_2026_06_23_us
    path: inbox/2026-06-23_广告数据_原始_US_V1.xlsx
    display_name: 2026-06-23 广告原始数据 US
    scenario: 广告运营
    file_type: input_data
    source: user_upload
    date_range: 2026-06-23
    used_by:
      - daily_ad_report
    can_overwrite: false
    retention: archive

  - file_id: ad_report_2026_06_23_us
    path: reports/2026-06-23_广告运营_日报_US_V1.md
    display_name: 2026-06-23 广告运营日报 US
    scenario: 广告运营
    file_type: final_report
    generated_by: daily_ad_report
    source_files:
      - ad_data_2026_06_23_us
    can_overwrite: false
    retention: keep
```

### 跨文件调用规则

每个 workflow 必须声明自己会读取、生成和更新哪些文件。

示例：

```yaml
workflow:
  id: daily_ad_report
  name: 每日广告日报
  reads:
    - data-sources.yaml
    - file-registry.yaml
    - inbox/*_广告数据_原始_*.xlsx
    - templates/广告运营_日报模板.md
  writes:
    - reports/{date}_广告运营_日报_{marketplace}_V{version}.md
    - logs/{date}_daily_ad_report_trace.json
    - usage-ledger/{month}_usage_cost.yaml
  updates:
    - file-registry.yaml
    - work.ws
  requires_confirmation_before:
    - overwrite_existing_file
    - send_to_group
    - update_external_system
```

这样做的价值是：

- Agent 不会随便找错文件。
- 用户能知道某份报告用了哪些来源。
- 后续复盘可以追溯。
- 多个 workflow 可以共享文件，但不会互相覆盖。
- 当文件缺失时，Agent 能准确告诉用户缺哪一个。

### 文件状态

每个重要文件都要有状态，避免用户分不清“草稿、最终版、已归档”。

建议状态：

| 状态 | 说明 |
|---|---|
| `inbox` | 用户刚放入，还没处理 |
| `validated` | 已检查格式和字段 |
| `working` | Agent 正在处理 |
| `draft` | 已生成草稿 |
| `final` | 已确认最终版 |
| `sent` | 已发送或同步 |
| `archived` | 已归档 |
| `error` | 文件有问题，需要处理 |

### 面向大众用户的文件交互

用户不需要说路径，只需要说清楚业务含义。

示例：

```text
把这个表作为今天的广告数据。
用昨天的广告数据生成日报。
找一下上周的利润复盘。
把这份日报改成最终版。
以后这个模板都用来写库存预警。
不要覆盖原文件，生成一个新版本。
```

Agent 应该回复用户能理解的话：

```text
我会把这个文件登记为 2026-06-23 的广告原始数据，放入“待处理文件”，并用于今天的广告日报。
```

而不是只说：

```text
已写入 inbox/xxx.xlsx。
```

### 工作治理检查

工作版保留约束系统，但规则要少而实用。

建议默认规则：

| 规则 | 说明 |
|---|---|
| W001 | `work.ws` 必须存在并能被读取 |
| W002 | 每个 workflow 必须绑定至少一个明确数据源或输入来源 |
| W003 | 每个数据源必须声明权限：只读、可写、需确认、禁止访问 |
| W004 | 涉及敏感字段的数据源必须声明脱敏规则 |
| W005 | 自动化任务必须记录执行日志和成本日志 |
| W006 | 高风险动作必须有人工确认点 |
| W007 | 报告类任务必须声明数据日期范围和来源 |
| W008 | 关键指标必须有计算口径，不能只给结论 |
| W009 | workflow 失败时必须说明失败原因和可恢复动作 |
| W010 | 月度成本超预算时必须暂停或请求确认 |
| W011 | 重要输入、输出和模板文件必须登记到 `file-registry.yaml` |
| W012 | 最终报告必须符合固定命名规范 |
| W013 | workflow 必须声明读取、写入和更新的文件 |
| W014 | 覆盖、删除、移动重要文件必须请求确认 |
| W015 | 报告必须记录来源文件，支持跨文件追溯 |

个人版不需要追求一开始就启用大量治理规则。先用少量高价值规则跑顺，再逐步增加。

### 工作执行循环

工作场景里的执行循环主要做六件事：

1. 执行任务前读取 `work.ws` 和相关数据源状态。
2. 明确任务目标、日期范围、输出格式和权限边界。
3. 执行数据读取、分析、生成报告或提出建议。
4. 交付前验证关键指标、来源、异常值和高风险动作。
5. 记录执行日志、Token 使用、工具调用和估算成本。
6. 根据用户反馈更新规则、偏好和 workflow。

推荐保留五种模式：

| 模式 | 用途 |
|---|---|
| single | 临时任务，跑一轮后交付 |
| daily | 日报类固定任务，例如广告日报、销量日报 |
| weekly | 周复盘类任务，例如选品复盘、利润复盘 |
| monitor | 监控类任务，例如库存预警、异常花费提醒 |
| recovery | 失败恢复或补跑任务，例如昨天数据缺失后重新生成 |

个人版默认使用 `single` 和 `daily`，等流程稳定后再启用 `monitor`。

### 多 Agent 分工

> 6 个 Agent 角色（主控/数据/分析/执行/审计/文档）的完整定义、协作协议和问责机制见 **Work Scenario Governance Spec §10（多 Agent 治理标准）**。
> 
> 这里不再重复定义。

### 跨场景通信

跨场景通信要保留，但要轻量。

它的作用是：当一个工作场景发生变化时，另一个相关场景可以知道。

适合工作场景的四类联动：

| 场景 | 例子 |
|---|---|
| 指标联动 | 广告 ACoS 异常，利润复盘 workflow 收到提醒 |
| 库存联动 | 库存不足，广告放量建议自动降级为谨慎 |
| 客户联动 | 客户投诉集中出现，产品优化和客服跟进 workflow 收到提醒 |
| 会议联动 | 会议纪要产生待办，日报或项目跟进 workflow 自动引用 |

个人版不需要完整消息总线。建议用一个轻量的 `work-hub.ws` 做跨场景索引。

目录结构可以是：

```text
.qianlima/
  work.ws
  work-hub.ws
  file-registry.yaml
  data-sources.yaml
  naming-rules.yaml
  workflows/
  templates/
  inbox/
  working/
  rules/
  reports/
  exports/
  archive/
  logs/
  usage-ledger/
  feedback/
```

`work-hub.ws` 负责记录：

- 当前有哪些工作场景
- 场景之间有哪些指标或任务关联
- 哪些规则、模板和经验可以共享
- 哪些文件被多个 workflow 调用
- 哪些报告依赖同一批来源数据
- 最近有哪些跨场景事件

跨场景事件示例：

```yaml
event:
  type: inventory_risk
  source_scenario: inventory_monitor
  target_scenario: ad_ops
  summary: "ASIN B0XXXX 库存低于 14 天安全线"
  suggested_task: "降低该 ASIN 的广告放量建议优先级"
  risk_level: medium
```

### Workflow 与 Skill 系统

工作版 Skill 不按编程任务设计，而是按工作流设计。

建议默认 8 个：

| Workflow / Skill | 用途 |
|---|---|
| daily-ad-report | 每日广告消耗、ACoS、异常广告组和建议 |
| sales-ledger | ASIN 销量、销售额、订单和趋势台账 |
| inventory-monitor | 库存预警、断货风险、补货优先级 |
| profit-review | 毛利率、TACoS、费用和利润复盘 |
| product-selection | 选品分析、竞品拆解、市场机会判断 |
| meeting-summary | 会议纪要、待办拆解、后续跟进 |
| customer-followup | 客户、供应商或合作方跟进提醒 |
| usage-cost-review | Token、模型调用、自动化成本和 ROI 复盘 |

### 保留与暂缓

工作版保留：

- `work.ws`
- `file-registry.yaml`
- 固定文件命名规范
- 固定工作目录
- 跨文件调用关系
- 数据源索引
- 基础治理规则
- workflow 执行日志
- 权限与隐私保护
- Token 和成本台账
- 多 Agent 分工
- 轻量跨场景通信
- 共享规则、模板和经验

工作版暂缓：

- 重型 UI
- 复杂团队权限系统
- 完整企业级审批流
- 大规模消息总线
- 全自动写入业务系统
- 无人工确认的自动调价、转账、删除、外发
- 复杂的组织级内部计费

### 推荐路线

第一阶段：单场景跑通

- 建立 `work.ws`
- 建立 `file-registry.yaml`
- 建立固定文件命名规则
- 登记一个真实数据源
- 跑通广告日报 workflow
- 记录执行日志和成本日志
- 建立基础验收规则

第二阶段：多工作流扩展

- 增加销量台账
- 增加库存预警
- 增加利润复盘
- 统一指标口径和报告模板
- 统一输入文件、输出报告和归档规则

第三阶段：跨场景联动

- 建立 `work-hub.ws`
- 让广告、库存、利润、选品之间共享关键事件
- 建立跨文件来源追溯
- 支持异常提醒和联动任务

第四阶段：再考虑 UI 和更深自动化

- 有稳定 workflow 后再做可视化面板
- 有明确收益后再接更多 ERP/API
- 有足够信任后再开放部分写入动作

### 最终形态

千里马计划的最终形态不是一个偏开发的 Agent 框架，而是一个稳定的个人/企业工作治理中枢。

它应该做到：

- 看得清个人或企业当前有哪些关键工作场景
- 找得到每个工作场景的固定文件、模板、报告和历史归档
- 管得住数据源、权限、成本和风险
- 调得动多个 Agent 协作完成真实工作
- 记得住历史问题、处理经验和用户偏好
- 能在广告、销售、库存、利润、会议、客户等场景之间同步关键变化

最终目标：

**一个人或一个小团队，也能用多 Agent 管好多个真实工作场景，并且不被复杂基础设施拖累。**

## 数据上下文层要解决的问题

数据上下文层不是简单“连数据库”，而是解决四个问题：

1. 用户是谁：个人身份、角色、职责、偏好、权限、常用工作流。
2. 用户正在做什么：当前业务、任务、日程、邮件、文档、会议、客户、订单、广告、库存、财务和协作流程等。
3. 用户真正需要什么：从行为数据、业务数据和历史任务中判断潜在需求。
4. Agent 可以安全使用哪些数据：哪些能读，哪些能写，哪些需要确认，哪些完全不能碰。

## 数据接口类型

### 1. 结构化数据库

用于连接业务核心数据。

支持对象：

- MySQL
- PostgreSQL
- SQLite
- SQL Server
- BigQuery
- Snowflake
- Airtable
- 飞书多维表格
- Notion Database

典型数据：

- 用户表
- 订单表
- 商品表
- 客户表
- 广告表
- 财务表
- 项目表
- 任务表
- 工单表

### 2. SaaS 系统接口

用于连接企业日常工具。

包括：

- 飞书 / Lark
- Slack
- Notion
- Google Workspace
- Microsoft 365
- Trello / Jira / Linear
- GitHub / GitLab
- HubSpot / Salesforce
- ERP / CRM / BI 系统

### 3. 个人数据接口

用于理解个人工作节奏和偏好。

包括：

- 日历
- 邮件
- 待办事项
- 笔记
- 文件夹
- 浏览器书签
- 最近项目
- 常用联系人
- 历史对话

### 4. 文件与知识库

用于理解背景资料。

包括：

- PDF
- Word
- Markdown
- Excel
- PPT
- Wiki
- 产品文档
- SOP
- 会议纪要
- 合同
- 报告

### 5. 行为与反馈数据

用于推断需求和持续改进。

包括：

- 用户经常让 Agent 做什么
- 哪些任务经常失败
- 哪些结果被用户修改
- 哪些流程反复出现
- 哪些提醒经常被忽略
- 哪些数据用户每天都看

## 数据访问安全原则

不要让 Agent 直接自由查询数据库。数据库接入必须经过中间层。

推荐结构：

```text
Agent
  -> Data Context Layer
    -> Permission Guard
    -> Schema Registry
    -> Query Planner
    -> Safe Query Executor
    -> Result Summarizer
  -> Database / API / SaaS
```

Agent 只能提出“我需要什么信息”，由数据层负责判断：

- 能不能查
- 查哪张表
- 用什么字段
- 是否脱敏
- 是否需要用户授权
- 返回多少数据
- 是否允许写入

## 核心模块

### Usage & Cost Ledger / Budget Guard / Cost Optimizer

> 成本台账、预算控制和成本优化的完整定义见 **Work Scenario Governance Spec §7（成本治理标准）**。
> 
> 核心要点：
> - 每次 workflow 执行后记录 Token、工具调用、耗时、估算成本
> - 四档预算控制：🟢正常(<70%) → 🟡预警(70-90%) → 🟠警告(90-100%) → 🔴超限暂停
> - 能用规则判断的不调大模型，能聚合的不塞明细，能缓存的不重复读
> 
> 这里不再重复定义。

### Connector Registry：连接器注册中心

记录已经接入的数据源。

```json
{
  "source_id": "lark_base_ads",
  "type": "lark_base",
  "owner": "company",
  "permission": "read_only",
  "description": "广告消耗日报数据",
  "entities": ["campaign", "ad_group", "spend", "acos", "sales"],
  "risk_level": "medium"
}
```

### Schema Registry：数据结构注册表

让 Agent 知道有哪些数据，但不暴露所有细节。

```json
{
  "table": "ad_campaigns",
  "business_name": "广告活动表",
  "fields": [
    {"name": "campaign_id", "meaning": "广告活动 ID"},
    {"name": "spend", "meaning": "广告花费"},
    {"name": "sales", "meaning": "广告销售额"},
    {"name": "acos", "meaning": "广告 ACoS"}
  ],
  "allowed_operations": ["read", "aggregate"],
  "forbidden_operations": ["delete", "update"]
}
```

### User Context Profile：用户上下文档案

用于快速理解个人或企业需求。

个人版：

```json
{
  "role": "Amazon 运营负责人",
  "active_projects": ["新品选品", "广告优化", "库存管理"],
  "daily_workflows": ["查看广告消耗", "检查销量", "调整竞价"],
  "preferred_outputs": ["表格", "Markdown 报告", "飞书同步"],
  "risk_preferences": {
    "auto_write": false,
    "require_confirmation_before_external_action": true
  }
}
```

企业版：

```json
{
  "company_stage": "跨境电商增长期",
  "departments": ["运营", "广告", "供应链", "财务"],
  "core_metrics": ["销售额", "利润率", "库存周转", "ACoS"],
  "connected_systems": ["ERP", "飞书", "Amazon 数据源"],
  "priority_workflows": ["广告优化", "选品分析", "日报生成"]
}
```

### Need Discovery Engine：需求发现引擎

让 Agent 更快知道个人或企业需求。

它可以根据数据主动发现：

- 哪些任务每天重复
- 哪些指标异常
- 哪些流程耗时
- 哪些数据分散在多个系统
- 哪些决策需要人工频繁判断
- 哪些工作可以自动化
- 哪些 SOP 可以沉淀为 Agent workflow

示例输出：

```json
{
  "discovered_need": "广告日报自动生成",
  "evidence": [
    "用户每天上午查看广告消耗",
    "飞书表格中存在每日广告数据",
    "历史对话多次要求整理 ACoS 和花费"
  ],
  "suggested_workflow": "每日 9:30 自动拉取广告数据并生成 Markdown 报告",
  "estimated_value": "每天节省 20-30 分钟",
  "risk_level": "low"
}
```

### Permission & Privacy Guard：权限和隐私保护

规则：

- 默认只读
- 写入必须显式授权
- 删除必须二次确认
- 敏感字段默认脱敏
- 跨系统同步要确认
- 个人数据和企业数据隔离
- 每次数据访问都记录日志
- 用户可以查看 Agent 读过哪些数据

敏感数据包括：

- 密码
- Token
- 财务账户
- 个人身份信息
- 客户联系方式
- 员工薪资
- 合同金额
- 商业机密
- 未发布产品计划

## MVP 目标

用一个真实业务场景验证千里马计划的核心能力：

> Agent 连接真实业务数据，理解广告运营需求，自动生成每日广告诊断报告，并在安全边界内给出可执行建议。

第一版不追求全自动调价，也不直接改线上广告。

第一版只做三件事：

1. 读数据
2. 做诊断
3. 生成报告和建议

## 为什么选广告运营日报

这个场景适合 MVP，因为它具备几个特点：

- 高频：每天都要看。
- 数据明确：花费、销售额、订单、ACoS、CPC、转化率。
- 判断规则可定义：高花费无单、高 ACoS、低曝光、转化异常。
- 结果可验证：日报内容可以和原始数据对照。
- 价值直接：节省人工看表和整理报告的时间。
- 风险可控：第一版只建议，不自动执行。

## 数据接入范围

第一版建议只接一个数据源，最多两个。

优先选择：

1. 飞书多维表格 / 飞书表格：适合快速 MVP，权限和协作方便。
2. 领星 ERP 导出 CSV：适合本地验证，不依赖复杂 API。
3. 本地 SQLite / PostgreSQL：适合工程化验证，方便后面扩展。

如果已有 ERP API，可以后续再接。MVP 不建议一开始就做复杂 API 鉴权和稳定性处理。

## 核心数据表

### 1. 广告活动数据

```text
date                日期
marketplace         站点
account             店铺/账号
campaign_id         广告活动 ID
campaign_name       广告活动名称
ad_group_id         广告组 ID
ad_group_name       广告组名称
targeting_type      投放类型
keyword_or_asin     关键词或投放 ASIN
match_type          匹配方式
impressions         展示量
clicks              点击量
spend               花费
sales               广告销售额
orders              广告订单数
acos                ACoS
cpc                 CPC
ctr                 CTR
cvr                 CVR
```

### 2. 商品销售数据

```text
date                日期
marketplace         站点
account             店铺/账号
asin                ASIN
sku                 SKU
product_name        商品名称
sessions            访问量
units_ordered       销量
sales               销售额
conversion_rate     转化率
inventory           库存
gross_margin        毛利率
```

### 3. 商品基础信息

```text
asin                ASIN
sku                 SKU
product_name        商品名称
category            类目
target_margin       目标毛利率
target_acos         目标 ACoS
launch_stage        阶段：新品/成长/成熟/清仓
priority_level      优先级
owner               负责人
```

## 关键指标计算

```text
广告花费 = spend
广告销售额 = sales
广告订单数 = orders
ACoS = spend / sales
CPC = spend / clicks
CTR = clicks / impressions
CVR = orders / clicks
广告 ROI = sales / spend
自然销售估算 = 总销售额 - 广告销售额
TACoS = 广告花费 / 总销售额
```

注意事项：

- sales 为 0 时，ACoS 不能直接除。
- clicks 为 0 时，CPC 和 CVR 要为空或标记不可计算。
- impressions 为 0 时，CTR 要为空。
- 所有金额要统一币种。
- 日期范围必须明确，比如“昨天”对应具体日期。

## 诊断规则

> 6 条诊断规则的完整定义（触发条件、严重度、建议文案）见 **Work Scenario Governance Spec §3.2（Workflow 标准结构 → diagnostic_rules）**。
> 
> 概要：
> 1. 高花费无单 → 降竞价或暂停
> 2. ACoS 过高 → 降竞价 10-20%
> 3. 表现优秀 → 保留或加预算
> 4. 高点击低转化 → 检查页面转化
> 5. 低曝光 → 检查竞价/预算/搜索量
> 6. 预算消耗异常 → 检查预算和异常关键词
> 
> 这里不再重复定义。

## 日报结构

```markdown
# 广告运营日报

日期：
站点：
账号：
数据来源：

## 1. 核心概览

- 广告花费：
- 广告销售额：
- 广告订单数：
- 整体 ACoS：
- CPC：
- CTR：
- CVR：
- TACoS：

## 2. 今日重点结论

1.
2.
3.

## 3. 异常广告组

| 广告组 | 花费 | 销售额 | 订单 | ACoS | 问题 | 建议 |
|---|---:|---:|---:|---:|---|---|

## 4. 表现优秀广告组

| 广告组 | 花费 | 销售额 | 订单 | ACoS | CVR | 建议 |
|---|---:|---:|---:|---:|---:|---|

## 5. 需要人工确认的动作

| 动作 | 对象 | 原因 | 风险等级 |
|---|---|---|---|

## 6. 数据质量检查

- 缺失字段：
- 异常值：
- 日期范围：
- 未能验证项：

## 7. 执行记录

- 数据读取：
- 诊断规则：
- 报告生成：
- 验证结果：
```

## Agent 执行流程

> 完整的 7 步执行循环（CLOCK → PREFLIGHT → EXECUTE → VERIFY → RECORD → DELIVER → LEARN）见 **Work Scenario Governance Spec §9.1（执行循环）**。
> 
> 广告日报 MVP 的具体步骤对齐到该循环的 EXECUTE 阶段，在 workflow 定义的 `execution.steps` 中声明（见 Governance Spec §3.2）。
> 
> 这里不再重复定义。

## 权限策略

> 权限分层、默认权限矩阵、确认级别（🟢无需确认/🟡单次/🟠二次/🔴禁止）的完整定义见 **Work Scenario Governance Spec §6（权限治理标准）**。
> 
> 广告日报 MVP 适用：
> - 默认只读，写入必须显式授权
> - 禁止直接修改广告、删除数据、发送外部消息
> - 同步飞书群/创建任务/发邮件需确认
> - 调价/暂停广告/修改预算需二次确认
> 
> 这里不再重复定义。

## 数据访问日志

```json
{
  "run_id": "ad-report-2026-06-23",
  "user": "current_user",
  "data_sources": ["lark_base_ads"],
  "date_range": "2026-06-22",
  "operations": ["read", "aggregate", "generate_report"],
  "rows_read": 1240,
  "sensitive_fields_accessed": [],
  "write_actions": ["create_markdown_report"],
  "risk_level": "low"
}
```

## Token 使用与成本日志

每次任务运行都要生成使用量记录，并和数据访问日志、执行 Trace 关联。

```json
{
  "run_id": "ad-report-2026-06-23",
  "task_name": "广告运营日报",
  "model_usage": [
    {
      "model": "claude-opus-4-8",
      "step": "分析异常广告组并生成建议",
      "input_tokens": 18000,
      "output_tokens": 3200,
      "cached_tokens": 6000,
      "reasoning_tokens": 1200,
      "estimated_cost": 0.58
    }
  ],
  "tool_usage": [
    {
      "tool": "data_connector",
      "calls": 3,
      "rows_read": 1240,
      "duration_seconds": 12
    },
    {
      "tool": "report_writer",
      "calls": 1,
      "files_written": 1,
      "duration_seconds": 2
    }
  ],
  "total_input_tokens": 18000,
  "total_output_tokens": 3200,
  "total_cached_tokens": 6000,
  "total_reasoning_tokens": 1200,
  "total_estimated_cost": 0.58,
  "currency": "USD",
  "budget_limit": 3.0,
  "budget_used_ratio": 0.193,
  "cost_center": "广告运营"
}
```

## 成本复盘指标

每周或每月汇总一次，判断自动化是否值得继续运行。

核心指标：

- 总运行次数
- 成功运行次数
- 失败运行次数
- 总 Token 消耗
- 总估算费用
- 单次平均费用
- 单次平均耗时
- 每份报告成本
- 每个有效建议成本
- 每小时节省人工成本
- 任务 ROI：节省人工价值 / AI 使用成本

广告日报场景可以这样看：

```text
月运行次数：30 次
月 AI 成本：30 美元
人工节省：每天 20 分钟，月节省约 10 小时
如果人工时间按 20 美元/小时估算，月节省价值约 200 美元
任务 ROI = 200 / 30 = 6.67
```

## 成本展示原则

对用户展示时不要把成本埋在系统日志里。重要任务应在最终报告中展示简短用量摘要。

示例：

```text
本次运行读取 1240 行广告数据，调用模型 1 次，估算消耗 21200 Token，估算成本 0.58 美元，用时 186 秒。
```

展示规则：

- 低成本普通任务：只记录，不强提示
- 自动化定时任务：日报或周报中展示成本
- 高成本任务：执行前提示预计成本区间
- 超预算任务：暂停并请求确认
- 企业场景：按用户、部门、项目、workflow 汇总

## 验收标准

MVP 通过标准：

1. 能连接至少一个真实广告数据源。
2. 能读取指定日期的数据。
3. 能正确计算核心指标。
4. 能识别至少 5 类异常或机会。
5. 能生成结构化日报。
6. 能列出数据来源和日期范围。
7. 能标记高风险动作，不自动执行。
8. 能输出执行日志。
9. 人工抽查 10 条广告组，判断结果基本一致。
10. 运行失败时能说明失败原因，而不是直接给空报告。
11. 能记录本次任务的 Token 使用量、模型调用次数、工具调用次数和估算成本。
12. 能设置单次任务预算，超出预算时停止或请求确认。
13. 能按 workflow 汇总每日、每周或每月使用成本。

## 第一版实现计划

> MVP 落地路线图已统一为三阶段计划，见 **Work Scenario Governance Spec §12（MVP 落地检查清单）**：
> 
> - **Phase 1**：单场景跑通（广告日报 MVP）— 注册数据源、定义 workflow、试跑验证
> - **Phase 2**：治理规则启用 — W001-W005 + 预算控制 + 用户偏好
> - **Phase 3**：多 workflow 扩展 — 销量台账、库存预警、跨场景联动
> 
> 本文件原来的 7 天计划对应 Phase 1 的详细日拆解，不再单独维护。

## 后续升级方向

第一版跑通后，再升级：

- 接入飞书自动发送
- 接入 ERP API
- 加入 7 日 / 14 日趋势
- 加入商品毛利率，计算目标 ACoS
- 加入库存约束，避免缺货商品继续放量
- 加入关键词排名数据
- 加入调价建议幅度
- 加入“用户确认后执行调价”
- 加入自动每日定时运行
- 加入异常主动提醒
- 加入学习用户过去采纳了哪些建议

## 这版 MVP 的核心价值

它不仅是一个广告日报工具。它是在验证千里马计划的核心闭环：

```text
连接真实数据
  -> 理解业务状态
  -> 发现问题
  -> 给出建议
  -> 验证结果
  -> 记录过程
  -> 统计成本
  -> 持续优化
```

加入 Token 花费和使用情况记录后，它还能回答一个关键问题：

> 这个 Agent workflow 到底值不值得长期自动运行？

这对个人和企业都很重要。个人用户需要知道哪些自动化真的省时间；企业用户需要知道每个部门、项目和 workflow 的 AI 成本是否合理。

如果这个闭环跑通，后面就可以复制到：

- 库存预警
- 选品分析
- 利润监控
- 客户跟进
- 竞品监控
- 日程助理
- 文档、数据和流程自动化
- 企业知识库问答
- 自动化工作流推荐

## Token 与成本模块的后续升级方向

- 接入不同模型的实时价格表
- 按模型、用户、项目、部门、workflow 做成本看板
- 自动识别高成本低价值任务
- 为不同任务推荐合适模型
- 对重复任务建立缓存和摘要复用
- 给每个自动化 workflow 计算 ROI
- 成本异常时自动提醒负责人
- 企业场景支持成本分摊和内部计费
- 对长任务提供执行前成本预估
- 把 Token 用量、数据读取量和结果质量关联分析

## 下一步建议

下一份文档建议写：

> Data Connector Spec 数据连接器标准

这是整个系统能不能规模化的关键，因为未来所有个人和企业数据都要通过这个标准安全接进来。

同时可以补一份：

> Work Scenario Governance Spec 工作场景治理标准

它用于定义 `work.ws`、workflow、权限规则、成本台账、跨场景事件和验收标准