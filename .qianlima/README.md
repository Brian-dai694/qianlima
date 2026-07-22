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
| `rules/browser-space-policy.md` | 浏览器任务空间规则 |
| `observability.yaml` | 工作流、经验、决策、文件和成本观测指标 |
| `evaluation-tasks.yaml` | 每个 workflow 的质量评估任务 |
| `qianlima-eval.yaml` | QianlimaEval 多维评分配置：意图、证据、执行、成本、风险 |
| `improvement-loop.yaml` | 从失败和反馈到规则改进的闭环 |
| `context-policy.yaml` | 自动上下文压缩、文件读取上限和安全冗余 |
| `model-adapters.yaml` | 面向 DeepSeek、OpenAI、Anthropic、Google、本地模型的适配策略 |
| `model-pricing.json` | 官方模型价格目录：输入、缓存命中和输出按百万 Token 独立计价 |
| `response-policy.yaml` | L0-L4 快速判级、3 秒阶段成果、证据等级、热状态和审计升级规则 |
| `task-runtime.yaml` | 轻量状态机、检查点、SWR、工具健康和延迟观测运行规则 |
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

## 体验优先响应

v2.6.9 起，每个任务先按 `response-policy.yaml` 判定 `L0-L4`，并在 3 秒内给出路线、已知事实、排除项或可操作判断。首轮结论必须标注证据等级：`A=实时数据`、`B=近期缓存`、`C=历史记录或假设`。只有任务升级为决策、报告、跨源证据或高风险执行时，才补齐完整 trace 和评估包。

会话内可以复用脱敏热状态和任务记忆卡；来源过期、规则变更或高风险执行前必须刷新。执行环境应先过滤和聚合数据，再将必要摘要交给模型。

## 轻量任务运行内核

v2.7.0 使用 `task-runtime.yaml` 管理任务状态：`classify -> initial_judgment -> evidence_collection -> decision_delivery -> confirmation_gate`。长任务先创建任务合同，任何外部读取前检查预算和用户控制；超时或中断时冻结已获得的证据与待验证项，不将半成品标记为完成。

快照采用 SWR：合格快照可用于初判，实时结果可推翻初判；价格、竞价、预算、采购、删除、外部写回前必须刷新原始来源并走确认门禁。原始 CSV 必须先经过 `scripts/summarize-csv.ps1` 本地聚合，保留公式版本与重跑入口。工具健康与体验事件仅存本地运行目录，用来诊断“慢在哪里”并验证优化没有降低证据完整率。

## 执行计划与 EVR（v2.7.9）

千里马的业务 Workflow 可以编译为结构化 `Execution Plan`，再由本地只读 Runner 执行。执行器只处理计划声明的步骤，不负责业务判断，也不能临时增加工具、预算或数据范围。

```text
Execution Plan
  -> Execute（按计划读取和计算）
  -> Verify（核对来源、行数、警告、待验证项和产物哈希）
  -> Revise（发现缺口时生成新计划引用）
  -> Completed / Frozen / Stopped
```

个人版首期只开放本地只读数据处理：CSV 使用 `scripts/invoke-qianlima-readonly-runner.ps1` 和既有 `scripts/summarize-csv.ps1`；XLSX、Python 只做预检，不自动安装依赖。默认无网络、无 ERP、无写回、无删除、无密钥读取、无二次委派。

示例入口：

```powershell
$steps = '[{"step_id":"aggregate","action":"read_selected_sources","input_refs":[".qianlima/tmp/report.csv"],"allowed_tools":["local_csv_reader","compute_metrics"],"expected_output":"numeric_summary","verification":"row count and metric fields are present"}]'
powershell -File .qianlima/scripts/new-qianlima-execution-plan.ps1 -PlanId report-001 -TaskId report-001 -Workflow daily_ad_report -Goal 'Aggregate a selected local CSV' -DataScope '.qianlima/tmp' -StepsJson $steps
powershell -File .qianlima/scripts/invoke-qianlima-evr.ps1 -Action execute -PlanPath .qianlima/run-traces/execution-plans/report-001.json
powershell -File .qianlima/scripts/invoke-qianlima-readonly-runner.ps1 -PlanPath .qianlima/run-traces/execution-plans/report-001.json -StepId aggregate -InputPath .qianlima/tmp/report.csv -NumericColumn spend,sales -GroupBy campaign
powershell -File .qianlima/scripts/invoke-qianlima-evr.ps1 -Action verify -PlanPath .qianlima/run-traces/execution-plans/report-001.json
```

计划、步骤回执和 EVR 事件均写入 `.qianlima/run-traces/`，产物只作为候选结果，必须通过验证后才算完成。合同定义见 `specifications/qianlima-*-contract.json`。

## 借鉴 AHE 的三项能力

- 组件可观测：每个 workflow 的数据源、模板、规则、输出和成本都能追踪。
- 经验可观测：用户采纳、拒绝、修改过的建议会进入反馈记录。
- 决策可观测：每条建议都要能追溯到数据来源、规则和风险等级。

## QianlimaEval 入口

v2.6.8 起，千里马吸收 MiniAppBench / MiniAppEval 的多维评估思想。非简单任务完成后，优先用 `qianlima_eval` workflow 或 `.qianlima/scripts/new-qianlima-eval-report.ps1` 生成评估报告。报告、trace 与用量台账必须互相引用同一产物，否则评测直接阻断。

评估维度：

- `intent_alignment`：是否理解用户真实目标。
- `evidence_static_quality`：报告结构、来源、待验证项是否完整。
- `dynamic_execution_quality`：trace、工具结果、验证门禁是否支持结论。
- `cost_savings_efficiency`：是否展示实时成本、节约和模型选择理由。
- `risk_control`：高风险动作是否阻断或确认。

默认规则：0.80 以上通过，0.60-0.80 复核，低于 0.60 阻断。凭证泄漏、未确认写回、高风险动作未确认直接阻断。

## NotebookLM 入口

NotebookLM 适合先消化长资料，再交给千里马继续做任务卡、报告和行动项。

普通用户可以把它当成“先帮我看完”的入口。

## 自动上下文压缩

Agent 不应该把所有文件一次性塞进模型上下文。遇到长文档、多文件或长任务时，先按 `context-policy.yaml` 自动压缩，只保留必要摘要、来源路径和待验证点，并预留安全上下文给推理、工具结果和最终输出。

## Skill 自进化

`skill_evolution` 先把用户纠正、失败和高价值成功案例写为私有反馈记录，再将问题映射到路由层、指令层或资源层，生成候选 Patch。候选必须带证据、成功指标和回滚计划，并通过留出案例验证和人工确认后才能进入生产 Skill。细分规则优先下沉到资源层，按月执行 compaction，避免主 Skill 膨胀。

v2.6.1 起，压缩摘要被视为安全敏感操作。涉及高风险动作、跨 Agent 交接或长文件摘要时，必须按 `rules/compression-attack-defense.md` 保留约束、来源段落和待验证项；不得仅凭摘要执行高风险动作。

## 成本节约原则

v2.6.2 起，实时显示成本和节约是中心思想。非简单任务必须输出成本状态：本次估算、预算上限、相比基线节约、主要节约来源，以及是否值得继续。详细规则见 `rules/cost-savings-principle.md`。

v2.6.3 起，成本状态卡有统一模板和生成脚本：`templates/realtime-cost-card_template.md` 与 `scripts/new-cost-card.ps1`。Agent 不应自由改字段顺序。脚本输出使用 ASCII，中文展示以模板为准。

## Browser Task Space 入口

v2.6.8 起，千里马吸收 ego-lite 的 Space / Snapshot / Skills 设计理念，但不强制安装 ego-lite。凡是 Kimi WebBridge、Chrome DevTools、桌面端 Agent 或未来 ego-lite 类工具操作已登录浏览器时，必须先按 `browser_task_space` 声明任务空间、目标网站、允许动作、禁止动作和接管路径。

执行原则：

- 先语义快照，再动作。
- 页面变化后重新快照。
- 登录态下的提交、发布、发送、删除、采购、改价、调竞价、调预算、账号权限变更必须走风险确认。
- 非简单浏览器任务要输出实时成本卡，并说明通过快照、批处理、复用路径节约了什么。

## 启动索引

大模型打开千里马计划后，必须先运行根目录 `start-qianlima.ps1` 生成索引，再读取 `WORKSPACE_INDEX.md`、`CODEX_BOOT.md` 和 `risk-rules.yaml`。随后先选择任务卡，只按需读取对应 workflow、template、数据文件和治理文件。长文件或多文件任务再读取 `context-policy.yaml`；需要模型选择或成本预估时再读取 `model-adapters.yaml`。该文件由 `scripts/bootstrap-qianlima.ps1` 生成，用来索引任务卡、workflow、模板、playbook 和延迟加载的治理文件。

普通用户可以使用根目录 `启动千里马计划.ps1` 作为中文入口。Agent 和自动化工具优先使用 `start-qianlima.ps1`。

DeepSeek 优先适配在 `model-adapters.yaml` 中维护。`deepseek-v4-flash` 用于低成本批量任务，`deepseek-v4-pro` 用于复杂推理和高价值分析。

## 模型计费

使用 `.qianlima/scripts/get-model-cost.ps1` 按官方价格目录计算输入、缓存命中和输出成本；使用 `new-usage-record.ps1 -AutoPrice` 自动把结果写入台账。目录中只有标记为 `verified` 的模型可以输出精确金额。其余厂商保留官方来源，但会返回 `source_only`，要求先刷新价格，避免把过期价格写进成本卡。

## 通义灵码 / Qoder CN 入口

v2.6.4 起，通义灵码和 Qoder CN 优先读取根目录 `QODER.md` 与 `LINGMA.md`。这两个文件只用于 Git-safe 工程维护，不用于真实运营写回。

## LinkAI Cloud 入口

v2.6.5 起，LinkAI Cloud 优先读取根目录 `LINKAI.md`，并使用 `templates/linkai-agent-prompt_template.md` 作为 Agent Prompt。LinkAI 只用于 Git-safe 知识库问答、多渠道入口和安全下一步建议，不用于真实业务写回。

## Obsidian 本地知识库入口

v2.6.6 起，Obsidian 优先读取根目录 `OBSIDIAN.md`，并使用 `rules/obsidian-vault-policy.md`、`templates/obsidian-note_template.md` 和 `templates/obsidian-moc_template.md`。Obsidian 用于本地知识沉淀和双链复盘，不作为真实业务写回执行层。
