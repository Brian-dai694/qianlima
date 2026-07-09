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
| `natural-language-router.yaml` | 自然语言触发路由：把普通业务说法映射到 skill、workflow 和 MCP |
| `user-preferences.yaml` | 用户偏好 |
| `risk-rules.yaml` | 权限和风险规则 |
| `rules/cost-savings-principle.md` | 成本节约中心原则 |
| `rules/compression-attack-defense.md` | 压缩攻击防御规则 |
| `observability.yaml` | 工作流、经验、决策、文件和成本观测指标 |
| `evaluation-tasks.yaml` | 每个 workflow 的质量评估任务 |
| `improvement-loop.yaml` | 从失败和反馈到规则改进的闭环 |
| `context-policy.yaml` | 自动上下文压缩、文件读取上限和安全冗余 |
| `model-adapters.yaml` | 面向 DeepSeek、OpenAI、Anthropic、Google、本地模型的适配策略 |
| `world-model.yaml` | 轻量世界模型层：预测数据需求、风险点和下一步动作 |

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

- 帮我做【任务】，数据在【文件/文件夹/链接/系统】，输出【结论/报告/Excel/建议】，权限是【只读/可写回】
- 管理技能，健康检查并分组，按 P0/P1/P2/P3 给我安装优先级
- 自动规划技能路径，告诉我这个任务该先用哪些 skill、workflow 和 MCP
- 我要做竞品对比
- 帮我优化这个 Listing
- 算一下这个产品赚不赚钱
- 跑一下这些关键词排名
- 帮我判断这个品类能不能做
- 先帮我整理这批资料

Agent 必须先用 `natural-language-router.yaml` 的 `auto_match_protocol` 自动匹配用户任务，再路由到对应 skill、workflow 或 MCP。用户不需要说技能名。业务 skill 优先，OfficeCLI、Chrome DevTools、Pangolinfo、Sorftime 等工具作为执行手段；低置信度或高风险动作必须先问一句或二次确认。

## 借鉴 AHE 的三项能力

- 组件可观测：每个 workflow 的数据源、模板、规则、输出和成本都能追踪。
- 经验可观测：用户采纳、拒绝、修改过的建议会进入反馈记录。
- 决策可观测：每条建议都要能追溯到数据来源、规则和风险等级。

## NotebookLM 入口

NotebookLM 适合先消化长资料，再交给千里马继续做任务卡、报告和行动项。

普通用户可以把它当成“先帮我看完”的入口。

## 自动上下文压缩

Agent 不应该把所有文件一次性塞进模型上下文。遇到长文档、多文件或长任务时，先按 `context-policy.yaml` 自动压缩，只保留必要摘要、来源路径和待验证点，并预留安全上下文给推理、工具结果和最终输出。

v2.6.1 起，压缩摘要被视为安全敏感操作。涉及高风险动作、跨 Agent 交接或长文件摘要时，必须按 `rules/compression-attack-defense.md` 保留约束、来源段落和待验证项；不得仅凭摘要执行高风险动作。

## 成本节约原则

v2.6.2 起，实时显示成本和节约是中心思想。非简单任务必须输出成本状态：本次估算、预算上限、相比基线节约、主要节约来源，以及是否值得继续。详细规则见 `rules/cost-savings-principle.md`。

v2.6.3 起，成本状态卡有统一模板和生成脚本：`templates/realtime-cost-card_template.md` 与 `scripts/new-cost-card.ps1`。Agent 不应自由改字段顺序。脚本输出使用 ASCII，中文展示以模板为准。

## 启动索引

大模型打开千里马计划后，必须先运行根目录 `start-qianlima.ps1` 生成索引，再读取 `WORKSPACE_INDEX.md`。该文件由 `scripts/bootstrap-qianlima.ps1` 生成，用来强制索引任务卡、workflow、模板、playbook、治理文件和模型适配策略。

普通用户可以使用根目录 `启动千里马计划.ps1` 作为中文入口。Agent 和自动化工具优先使用 `start-qianlima.ps1`。

DeepSeek 优先适配在 `model-adapters.yaml` 中维护。`deepseek-v4-flash` 用于低成本批量任务，`deepseek-v4-pro` 用于复杂推理和高价值分析。

## 通义灵码 / Qoder CN 入口

v2.6.4 起，通义灵码和 Qoder CN 优先读取根目录 `QODER.md` 与 `LINGMA.md`。这两个文件只用于 Git-safe 工程维护，不用于真实运营写回。

## LinkAI Cloud 入口

v2.6.5 起，LinkAI Cloud 优先读取根目录 `LINKAI.md`，并使用 `templates/linkai-agent-prompt_template.md` 作为 Agent Prompt。LinkAI 只用于 Git-safe 知识库问答、多渠道入口和安全下一步建议，不用于真实业务写回。
