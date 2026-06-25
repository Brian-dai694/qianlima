# Cross-File and Cross-Project Communication Protocol 跨文件与跨项目通信协议

## 结论

千里马计划已经有跨文件和跨场景通信的基础，但之前还不算完善。

已有能力：

- `file-registry.yaml` 记录文件位置、用途和调用关系。
- `work.ws` 记录工作场景、当前重点、数据源和 workflow。
- `work-hub.ws` 作为轻量跨场景事件中枢。
- `execution_context` 规则约定多 Agent 之间通过执行上下文传递状态。
- `context-policy.yaml` 规定长文件、多文件和上下文压缩。

主要缺口：

- 没有统一的引用格式。
- 没有统一的跨文件、跨项目消息结构。
- 没有明确规定大文件、长资料、模型交接时传原文还是传摘要。
- 没有把跨项目共享和隐私脱敏绑定起来。
- 校验脚本没有把通信协议当作骨架必需文件。

现在补充的核心文件是：

```text
.qianlima/communication-protocol.yaml
```

它把跨文件、跨 workflow、跨场景、跨项目、跨 Agent 的通信规则统一起来。

## 设计目标

通信协议不是为了做复杂平台，也不是为了让普通用户学习技术概念。

它解决的是三个实际问题：

1. 文件多了以后，大模型知道该读哪个、不该读哪个。
2. 项目多了以后，大模型知道哪些文件、事件、结论可以互相引用。
3. 为用户节省 token，同时提升大模型对真实工作场景的理解和执行质量。

## 基本原则

- 能传引用，就不要传全文。
- 能传摘要，就不要重复读长文。
- 原始文件始终是事实来源，摘要只用于降低上下文成本。
- 跨项目共享必须默认脱敏。
- 所有关键结论都要能追溯到来源文件、数据源、事件或执行记录。
- 高风险动作不能只依赖摘要，必须回读来源片段。

## 统一引用格式

Agent 之间、workflow 之间、项目之间不要随意说“那个文件”“之前的报告”。

统一使用下面的引用：

```text
file:{file_id}
file:{file_id}#section={heading_or_anchor}
data:{data_source_id}:{view_or_query_id}
run:{run_id}
event:{event_id}
scenario:{scenario_id}
project:{project_id}
summary:{summary_id}
```

示例：

```text
file:context_policy#section=auto_compression_triggers
data:sample_ads_daily:daily_snapshot
run:daily-ad-report-2026-06-25-001
event:inventory_low_2026_06_25_001
summary:long-doc-2026-06-25-001
```

这些引用分别通过 `.qianlima/file-registry.yaml`、`.qianlima/data-sources.yaml`、`.qianlima/work.ws`、`.qianlima/work-hub.ws`、`.qianlima/logs/` 和 `.qianlima/context-summaries/` 解析。

## 五级通信方式

| 级别 | 名称 | 适用场景 | Token 策略 |
|---|---|---|---|
| L0 | 直接读取 | 小文件、当前任务必须读的配置 | 直接读，但受 `context-policy.yaml` 限制 |
| L1 | 只传引用 | 只需要知道来源或位置 | 不复制正文 |
| L2 | 摘要清单 | 长文件、多文件、模型交接 | 读摘要和来源路径 |
| L3 | 执行上下文 | 多步骤 workflow、多 Agent 协作 | 只传 run、step 和输出引用 |
| L4 | 跨项目包 | 项目之间复用经验、模板、结论 | 只传脱敏后的清单和摘要 |

## 跨文件调用

跨文件调用必须满足：

- 文件必须登记到 `.qianlima/file-registry.yaml`。
- 共享文件必须记录 `used_by`。
- 输出报告必须记录来源文件或数据源。
- 模板文件默认不允许覆盖。
- 多个 workflow 使用同一文件时，删除或覆盖前必须确认。

推荐流程：

```text
用户提出任务
  -> Agent 判断 workflow
  -> 读取 file-registry.yaml
  -> 找到输入文件、模板和输出位置
  -> 根据 context-policy.yaml 判断直接读、摘读还是摘要
  -> 执行任务
  -> 输出文件登记回 file-registry.yaml
  -> 使用情况写入 usage-ledger
```

## 跨项目通信

个人版不需要复杂消息总线，也不需要完整 A2A 协议。

跨项目默认使用“脱敏引用包”：

```yaml
package_id: qianlima_export_2026_06_25_001
source_project: project:source_workspace
target_project: project:target_workspace
created_at: "2026-06-25T10:00:00+08:00"
included_refs:
  - file:workflow_template
  - summary:ad_ops_lessons_2026_06
excluded_refs:
  - real_customer_data
  - account_tokens
privacy_check: passed
intended_use: Reuse workflow template and lessons learned.
```

默认可以共享：

- 公共说明文档
- 模板
- Schema
- 不含隐私的摘要
- 示例数据

需要用户确认后才能共享：

- 真实业务数据
- 客户或个人数据
- 账号标识
- 外部写入动作
- 私密 token 或成本台账

## 跨场景事件

跨场景事件仍由 `.qianlima/work-hub.ws` 管理。

事件示例：

```yaml
event:
  id: inventory_low_2026_06_25_001
  type: inventory_risk
  severity: high
  timestamp: "2026-06-25T10:00:00+08:00"
  source:
    scenario: inventory_monitor
    workflow: inventory_alert
  target:
    scenarios:
      - ad_ops
      - profit_review
    action_suggestion:
      for_ad_ops: Reduce ad scaling priority for affected ASIN.
      for_profit_review: Mark supply risk in weekly profit review.
  resolution:
    status: pending
```

## 多 Agent 协作

多 Agent 不直接互相聊天。

它们通过执行上下文通信：

```text
主控 Agent 创建 run_id
数据 Agent 写入数据读取结果
分析 Agent 读取数据结果并写入诊断
执行 Agent 生成报告
审计 Agent 检查来源、风险和成本
主控 Agent 更新 work.ws 和交付用户
```

大数据不直接塞进上下文，写入 `.qianlima/working/` 或 `.qianlima/logs/`，再传引用。

## 验收标准

一次跨文件或跨项目任务完成后，至少检查：

- 引用的文件是否存在。
- 输出是否记录来源。
- 是否使用了合适的压缩级别。
- 是否有高风险动作或隐私数据。
- 跨场景事件是否写入 `work-hub.ws`。
- 跨项目包是否完成隐私检查。
- token 和使用情况是否写入 `.qianlima/usage-ledger/`。

## 对普通用户的意义

用户不需要记文件名，也不需要知道哪个文件应该被哪个 workflow 调用。

用户只需要说：

```text
帮我整理这批资料。
把这个结论同步到广告日报。
以后利润复盘也要参考这个库存风险。
把这个模板复制给另一个项目，但不要带我的私密数据。
```

千里马协议负责让大模型知道：

- 去哪里找文件。
- 哪些内容可以读。
- 哪些内容只能引用。
- 哪些内容必须脱敏。
- 哪些结论需要回到来源验证。
- 如何用更少 token 完成更可靠的工作。
