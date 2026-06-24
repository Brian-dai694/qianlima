# 千里马计划 · 文档索引

> 一套面向 AI Agent 的高可靠执行与工作治理系统。让 Agent 连接真实数据、理解工作状态、安全可靠地执行任务，并持续优化。
> 更聚焦普通业务场景的 harness，让没有技术背景的人也能用自然语言启动任务、连接数据、生成报告并记录成本。

## 阅读顺序

### 启动前置步骤

任何大模型、Agent 或自动化工具打开本工作区后，先遵守 `AGENTS.md`，并运行启动索引：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\start-qianlima.ps1"
```

普通用户也可以使用 `启动千里马计划.ps1`。脚本会生成 `.qianlima/WORKSPACE_INDEX.md` 和 `.qianlima/workspace-index.json`，然后再按索引读取文件。详细规则见 `AGENTS.md` 和 `AI_START_HERE.md`。

| 顺序 | 文件 | 定位 | 读完能理解 |
|:---:|------|------|------|
| 1 | `AGENTS.md` | 🤖 Agent 项目规则 | 强制启动索引、按任务加载、禁止一次性读全库 |
| 2 | `AI_START_HERE.md` | 🚦 AI 启动入口 | 先运行启动脚本，生成工作区索引 |
| 3 | `.qianlima/WORKSPACE_INDEX.md` | 🧭 当前索引 | 本次应读取哪些治理文件、任务卡、模板和流程 |
| 4 | `Work Scenario Governance Spec 工作场景治理标准.md` | 🎯 治理中枢 | 整个系统怎么运转 — 时间、场景、workflow、权限、成本、跨场景联动 |
| 5 | `Data Connector Spec 数据连接器标准.md` | 🔌 数据接入 | 数据源怎么登记、授权、脱敏、校验、被 workflow 调用 |
| 6 | `Harness 千里马计划 MVP 数据上下文层与广告运营日报 Agent.md` | 🏗️ 系统架构 | 七层能力模型 + 广告日报 Agent 的完整设计（日报结构、指标计算） |
| 7 | `PWE-v2.0个人使用版-治理方案.md` | 📦 远期参考 | 代码项目管理方案。当前工作台无代码项目，以 `.qianlima/` 体系为准 |
| 8 | `AHE 借鉴清单与千里马适配方案.md` | 🔁 Harness 演化参考 | 组件可观测、经验可观测、决策可观测和改进闭环 |
| 9 | `AMZ-EVO 简单版融合说明.md` | 🧭 大众任务入口 | 如何把简单版亚马逊运营 harness 融合成普通人会用的任务卡 |
| 10 | `NotebookLM 融合说明.md` | 📚 资料消化入口 | 先整理长资料，再交给千里马做任务卡、报告和行动项 |
| 11 | `如何把千里马计划合并到大模型.md` | 🔧 模型接入说明 | 如何把 `.qianlima/` 作为外部工作台、上下文包和规则层接入大模型 |

## 实施入口

- **MVP 路线图**：见 `Work Scenario Governance Spec` §13（三阶段：单场景跑通 → 治理规则 → 多 workflow 扩展）
- **广告日报设计**：见 `Harness MVP` §日报结构
- **数据源登记**：见 `Data Connector Spec` §MVP 接入标准
- **大众任务入口**：见 `.qianlima/task-cards/`
- **亚马逊简单版流程**：见 `.qianlima/playbooks/amz-simple-playbook.yaml`
- **NotebookLM 资料消化**：见 `.qianlima/playbooks/notebooklm-simple-playbook.yaml`
- **自动上下文压缩**：见 `.qianlima/context-policy.yaml`
- **大模型适配**：见 `.qianlima/model-adapters.yaml`
- **Token 与费用记录**：见 `.qianlima/usage-ledger/` 和 `.qianlima/templates/token-usage-record_template.yaml`
- **模型接入说明**：见 `如何把千里马计划合并到大模型.md`
- **强制启动索引**：见 `AGENTS.md`、`AI_START_HERE.md`、`start-qianlima.ps1`、`.qianlima/WORKSPACE_INDEX.md`

## 大众可直接使用的说法

- 我要做竞品对比
- 帮我优化这个 Listing
- 算一下这个产品赚不赚钱
- 跑一下这些关键词排名
- 帮我判断这个品类能不能做
- 先帮我整理这批资料

## 上下文安全

千里马不会默认把所有文件一次性塞进大模型。长文件、多文件和长任务会先按 `.qianlima/context-policy.yaml` 自动压缩，默认只规划使用 70% 的模型上下文窗口，并保留 30% 安全冗余给推理、工具返回和最终输出。

模型适配不写死在业务流程里。DeepSeek、OpenAI、Anthropic、Google 和本地模型统一通过 `.qianlima/model-adapters.yaml` 配置。DeepSeek 优先支持 `deepseek-v4-flash` 和 `deepseek-v4-pro`，分别对应低成本批量任务和复杂推理任务。

## Token 与费用记录

千里马计划要求每次任务结束后记录模型使用情况。记录位置：

```text
.qianlima/usage-ledger/
```

记录模板：

```text
.qianlima/templates/token-usage-record_template.yaml
```

当前公开模板的最小启动包估算为 **10,655 到 19,534 input tokens**。这个估算包含：

```text
AI_START_HERE.md
.qianlima/WORKSPACE_INDEX.md
.qianlima/README.md
.qianlima/work.ws
.qianlima/workflow-index.yaml
.qianlima/risk-rules.yaml
.qianlima/context-policy.yaml
.qianlima/model-adapters.yaml
```

实际任务还要额外加上任务卡、workflow、模板、数据源、工具返回和最终输出。费用不要写死在文档里，应按当前模型供应商价格计算：

```text
估算费用 =
输入 tokens / 1,000,000 × 输入单价
+ 输出 tokens / 1,000,000 × 输出单价
+ 缓存输入 tokens / 1,000,000 × 缓存输入单价
```

每次输出报告时，最后必须附上简短使用摘要：

```text
模型：xxx
输入 tokens：xxx
输出 tokens：xxx
估算费用：xxx
是否使用上下文压缩：是/否
记录位置：.qianlima/usage-ledger/xxxx.yaml
```

## 文件间依赖

```text
Work Scenario Governance Spec  ← 权威定义（时间/场景/workflow/权限/成本/Agent）
    ├─ Data Connector Spec     ← 数据接入标准（被 Governance Spec §5 引用）
    ├─ Harness MVP             ← 架构 + 日报设计（重复定义已清理，指向 Governance Spec）
    └─ PWE v2.0                ← 远期参考（代码项目治理，已被 Governance Spec 吸收）

README.md                      ← 本文件
会话索引摘要-模板.md             ← 会话续接模板（MVP Phase 1 后启用）
```

## 当前状态

| 标准 | 文件 | 状态 |
|:---:|------|:---:|
| Harness MVP 架构 | `Harness MVP` | ✅ 已定义 |
| 数据连接器标准 | `Data Connector Spec` | ✅ 已定义 |
| 工作场景治理标准 | `Work Scenario Governance Spec` | ✅ 已定义 |
| PWE 治理方案 | `PWE v2.0` | ✅ 已定义（远期参考） |
| AHE 适配 | `AHE 借鉴清单` + `.qianlima/observability.yaml` | ✅ 已融合 |
| AMZ-EVO 简单版 | `AMZ-EVO 简单版融合说明` + `.qianlima/task-cards/` | ✅ 已融合 |
| NotebookLM | `NotebookLM 融合说明` + `.qianlima/task-cards/knowledge-digest.yaml` | ✅ 已融合 |
| 上下文治理 | `.qianlima/context-policy.yaml` + `.qianlima/context-summaries/` | ✅ 已定义 |
| 大模型适配 | `.qianlima/model-adapters.yaml` | ✅ 已定义，DeepSeek 优先适配 |
| MVP 实施 | — | ⏳ 待启动 |
