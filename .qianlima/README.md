# 千里马计划工作区骨架

这个目录是千里马计划的固定工作区，用来管理工作场景、数据源、文件、工作流、日志和成本。

面向大众用户时，不要求用户理解这些文件。用户只需要用自然语言说明：

- 这个文件是什么数据
- 要生成什么报告
- 是否允许发送、写回或修改外部系统
- 输出希望放在哪里

Agent 负责维护这些配置文件。

## 核心文件

| 文件 | 用途 |
|---|---|
| `work.ws` | 工作状态总索引 |
| `WORKSPACE_INDEX.md` | 大模型打开项目后的强制工作区索引入口 |
| `workspace-index.json` | 机器可读工作区索引 |
| `work-hub.ws` | 跨场景事件和联动索引 |
| `file-registry.yaml` | 文件注册表 |
| `data-sources.yaml` | 数据源注册表 |
| `naming-rules.yaml` | 文件命名规则 |
| `workflow-index.yaml` | 工作流索引 |
| `user-preferences.yaml` | 用户偏好 |
| `risk-rules.yaml` | 权限和风险规则 |
| `observability.yaml` | 工作流、经验、决策、文件和成本观测指标 |
| `evaluation-tasks.yaml` | 每个 workflow 的质量评估任务 |
| `improvement-loop.yaml` | 从失败和反馈到规则改进的闭环 |
| `context-policy.yaml` | 自动上下文压缩、文件读取上限和安全冗余 |
| `communication-protocol.yaml` | 跨文件、跨场景、跨项目和模型交接通信协议 |
| `runtime-protocol.yaml` | SessionStart、BeforeToolUse、AfterToolUse、FinalCheck 运行执行协议 |
| `decision-log.yaml` | 运营动作的证据、预期影响、验证窗口和实际结果记录模板 |
| `model-adapters.yaml` | 面向 DeepSeek、OpenAI、Anthropic、Google、本地模型的适配策略 |

## 固定目录

| 目录 | 用途 |
|---|---|
| `inbox/` | 用户放入的原始文件 |
| `working/` | Agent 处理中间文件 |
| `reports/` | 最终报告 |
| `templates/` | 固定模板 |
| `archive/` | 历史归档 |
| `logs/` | 执行日志 |
| `usage-ledger/` | Token、模型调用和成本台账 |
| `context-summaries/` | 长文件和多文件任务的结构化摘要 |
| `feedback/` | 用户反馈和规则修正 |
| `workflows/` | 工作流定义 |
| `rules/` | 治理规则 |

## 第一版内置工作流

- `daily_ad_report`：每日广告运营日报
- `competitor_comparison`：竞品对比
- `listing_optimization`：Listing 优化诊断
- `profit_check`：利润测算
- `keyword_monitoring`：关键词监控
- `product_discovery`：新品机会探索
- `knowledge_digest`：资料消化

## 大众使用入口

普通用户优先使用 `task-cards/`，不用直接编辑 workflow。

可以直接这样说：

- 我要做竞品对比
- 帮我优化这个 Listing
- 算一下这个产品赚不赚钱
- 跑一下这些关键词排名
- 帮我判断这个品类能不能做
- 先帮我整理这批资料

## 借鉴 AHE 的三项能力

- 组件可观测：每个 workflow 的数据源、模板、规则、输出和成本都能追踪。
- 经验可观测：用户采纳、拒绝、修改过的建议会进入反馈记录。
- 决策可观测：每条建议都要能追溯到数据来源、规则和风险等级。

## NotebookLM 入口

NotebookLM 适合先消化长资料，再交给千里马继续做任务卡、报告和行动项。

普通用户可以把它当成“先帮我看完”的入口。

## 自动上下文压缩

Agent 不应该把所有文件一次性塞进模型上下文。遇到长文档、多文件或长任务时，先按 `context-policy.yaml` 自动压缩，只保留必要摘要、来源路径和待验证点，并预留安全上下文给推理、工具结果和最终输出。

## 跨文件与跨项目通信

跨文件、跨 workflow、跨场景、跨项目和模型交接统一使用 `communication-protocol.yaml`。默认传引用和摘要，不重复搬运全文；跨项目共享默认走脱敏引用包，避免把个人、客户、账号、成本或 token 数据带入公开仓库或其他项目。

## 运行执行协议

千里马的规则必须进入执行链。`runtime-protocol.yaml` 固定四个检查点：SessionStart 识别场景并加载最小上下文；BeforeToolUse 检查权限和高风险动作；AfterToolUse 落盘原始工具输出并只把摘要带入上下文；FinalCheck 验证结果、写使用台账和决策日志。

## 启动索引

大模型打开千里马计划后，必须先运行根目录 `start-qianlima.ps1` 生成索引，再读取 `WORKSPACE_INDEX.md`。该文件由 `scripts/bootstrap-qianlima.ps1` 生成，用来强制索引任务卡、workflow、模板、playbook、治理文件和模型适配策略。

普通用户可以使用根目录 `启动千里马计划.ps1` 作为中文入口。Agent 和自动化工具优先使用 `start-qianlima.ps1`。

DeepSeek 优先适配在 `model-adapters.yaml` 中维护。`deepseek-v4-flash` 用于低成本批量任务，`deepseek-v4-pro` 用于复杂推理和高价值分析。
