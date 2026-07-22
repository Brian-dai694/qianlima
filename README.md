# 千里马 — 亚马逊运营 AI Agent Harness

[中文](README.md) · **English** → [README.en.md](README.en.md)

[![CI](https://github.com/Brian-dai694/qianlima/actions/workflows/qianlima-verify.yml/badge.svg)](https://github.com/Brian-dai694/qianlima/actions/workflows/qianlima-verify.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-v2.8.0-blue.svg)](CHANGELOG.md)
[![PowerShell](https://img.shields.io/badge/PowerShell-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)

> 版本: v2.8.0 | 2026-07-22 · 变更历史见 [CHANGELOG.md](CHANGELOG.md)

千里马计划是一个面向亚马逊卖家的 AI Agent Harness 系统。它不是另一个“关键词工具”或“广告管理面板”，而是 **Agent 治理层**：让 LLM 能可靠、安全、可追溯地执行亚马逊运营任务。v2.7.9 增加个人版渐进式治理、任务相关记忆选择、可清除的个人经验管理、唯一的显式本地 stdio 只读证据工具，以及个人学习管线边界。

## 核心理念

> Harness 不是 prompt 模板，而是运行时系统。  
> 它观察自己、诊断问题、积累经验，并持续自我改进。

本项目借鉴了 [Lilian Weng — Harness Engineering for Self-Improvement (2026)](https://lilianweng.github.io/posts/2026-07-04-harness/) 以及多个 SOTA 项目的设计理念。v2.7.8 延续分层启动、运行时策略、命令安全、评估、观测、记忆卡、子代理分工与状态化 Loop 的公开安全模板。

## 架构

```text
千里马 Harness v2.8.0
├── 场景智能路由      → 按场景精准加载，减少不必要上下文
├── 健康自检          → 启动时自动检查骨架、索引和引用
├── Loop Engineering  → SDR / EVR / PBV / EDA 执行循环
├── 进化式改进        → fix / tune / A/B / extract / evolve 闭环
├── 子代理编排        → 任务分工、资源限制和交接规范
├── Context 2.0       → 动态上下文分配、智能压缩、实时监控
├── 压缩攻击防御      → 防止摘要丢失约束、改写偏好或绕过安全规则
├── Policy Adapter    → 策略生成、环境观测、动作评分解耦
├── Skill 注册表      → trigger / scope / capability / quality gate 标准化
├── 自然语言路由      → 用户发任务后自动匹配 skill / workflow / MCP
├── 实时成本卡        → 每个非简单任务显示成本、节约、是否继续，使用统一模板
├── 分层启动          → L0-L4 按风险加载，缓存命中走快速状态检查
├── 运行时策略        → 预算、沙箱、状态机和 L4 二次确认
├── 命令安全 Hook     → 删除、覆盖、格式化和越界路径的前置拦截
├── QianlimaEval      → 来源、风险、账本和首答延迟的分层验收
├── Memory Cards      → 带来源、有效期与置信度的本地运营对象记忆
├── Maker / Checker   → 子代理上下文隔离，父代理保留外部决策权
├── 状态化 EVR Loop  → execute / verify / refine 可追溯循环
├── 多 Agent 入口     → Codex / Claude / Manus / Qoder CN / Lingma / LinkAI / Obsidian / 桌面端
├── 本地知识库        → Obsidian Vault、MOC、笔记模板、公私知识分离
├── KV Cache 优化     → 稳定前缀与缓存命中策略
├── 配置演化追踪      → forward / rollback / diff / audit 迁移记录
├── 个人只读 stdio    → 唯一工具、一次性 Grant、证据回执和拒绝回归
├── 个人学习管线      → 资源摘要、局部提案、只读执行和收敛验证
└── 个人 Governed Loop → Builder/Checker 隔离、原始检查回执和自动冻结
```

## 快速开始

### 1. 克隆仓库

```bash
git clone <repo-url>
cd qianlima
```

### 2. 配置私有数据

公开仓只保留脱敏模板。真实数据请只放在你的私有 fork 或本地工作副本中。

```bash
# 复制脱敏模板
cp .qianlima/data-sources.example.yaml .qianlima/data-sources.yaml
cp .qianlima/work.example.ws .qianlima/work.ws

# 然后在本地编辑真实数据
# data-sources.yaml: 飞书 token、ERP URL 等
# work.ws: ASIN、成本、利润率、关键词等
```

### 3. 初始化工作区

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\start-qianlima.ps1"
```

macOS / Linux（需先装 PowerShell 7，例如 `brew install --cask powershell`）：

```bash
./start-qianlima.sh
```

启动脚本会生成：

```text
.qianlima/WORKSPACE_INDEX.md
.qianlima/workspace-index.json
```

Agent 进入本仓库后，应先读取 `.qianlima/WORKSPACE_INDEX.md`，再按索引加载最小启动包。

不同 Agent 可使用专用入口：

- Codex：`AGENTS.md`、`.qianlima/CODEX_BOOT.md`
- Claude Code：`CLAUDE.md`
- Manus：`MANUS.md`、`.qianlima/MANUS_BOOT.md`
- 通义灵码 / Qoder CN：`QODER.md`、`LINGMA.md`
- LinkAI Cloud：`LINKAI.md`、`.qianlima/templates/linkai-agent-prompt_template.md`
- Obsidian：`OBSIDIAN.md`、`.qianlima/rules/obsidian-vault-policy.md`
- 桌面端产品：`DESKTOP_AGENT_BRIEF.md`

### 4. 触发任务

在 CodeWhale、Claude Code 或其他支持本仓库规则的 Agent 框架中，可以直接用自然语言触发：

- “跑一下关键词排名” → `keyword_rank_scan`
- “生成广告日报” → `daily_ad_report`
- “竞品对比” → `competitor_comparison`
- “算利润” → `profit_check`
- “管理技能，健康检查并分组” → `skill_management`
- “自动规划技能路径” → `skill_path_planning`

## 文件结构

```text
.qianlima/
├── work.example.ws              # 公开示例工作状态
├── data-sources.example.yaml     # 公开示例数据源配置
├── risk-rules.yaml               # 风险规则
├── rules/cost-savings-principle.md # 成本节约中心原则
├── rules/compression-attack-defense.md # 压缩攻击防御规则
├── context-policy.yaml           # 上下文策略
├── model-adapters.yaml           # 模型适配与 KV Cache 策略
├── meta-scenario-router.md       # 场景智能路由
├── workflow-index.yaml           # Workflow 索引
├── improvement-loop.yaml         # 进化式反馈闭环
├── harness-health-check.yaml     # 健康自检
├── loop-engineering.yaml         # Loop Engineering 框架
├── subagent-orchestration.yaml   # 子代理编排
├── evolutionary-workflow.yaml    # 进化式 Workflow
├── skill-registry.yaml           # Skill 注册表
├── task-cards/                   # 任务卡定义
├── workflows/                    # Workflow 定义
├── specifications/               # 可执行合同（个人版只读工具等）
├── local-a2a-agents.json         # 个人版本地 stdio 注册信息，无地址/监听器
├── templates/                    # 报告模板
└── playbooks/                    # 操作手册
```

## 隐私边界

本仓库是 **Git-safe 公开模板**，不应提交任何真实运营数据。

不要提交：

- API key、token、密码、cookie 或其他凭证
- 真实客户姓名、邮箱、电话、地址、合同信息
- 真实账号 ID、广告后台导出、ERP 导出、Marketplace 后台数据
- 私有成本台账、usage ledger、decision log、截图或报告
- 本地机器路径、用户目录或个人工作区路径

默认 `.gitignore` 会排除生成索引、运行日志、usage ledger、decision log、报告、截图、媒体文件和本地密钥文件。

发布或提交 PR 前，请运行公开安全校验：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\.qianlima\scripts\verify-qianlima.ps1"
```

## 自动校验

本仓库包含 GitHub Actions 工作流：

```text
.github/workflows/qianlima-verify.yml
```

该工作流会在 push 和 pull request 时执行：

- 启动索引和骨架校验
- public-safe 严格校验
- runtime 安全门检查
- 未确认高风险动作拦截检查

## Runtime 辅助脚本

个人版学习/研究任务采用四段式管线：`资源摘要 -> 局部计划 -> 受控只读执行 -> 验证收敛`。普通任务默认只返回摘要或提案，不自动安装 Skill、不联网、不启动后台循环；只有用户显式继续并提供匹配 Grant，才可使用唯一的本地只读证据工具。计划边界校验：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\.qianlima\scripts\test-personal-learning-boundary.ps1"
```

个人版代码和本地只读任务可使用 Governed Loop：Builder 只处理任务选定范围，Checker 只读检查，编排器原样保留 Checker 输出并应用停止规则。默认最多 5 轮；同一失败连续 2 次、回归、连续 2 轮无进展、超时或越权会自动冻结，不会扩大 Grant、数据范围或预算。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\.qianlima\scripts\test-personal-governed-loop.ps1"
```

个人版只预留一个显式启动的本地只读工具：`qianlima_readonly_evidence_task`。千里马内部生成匹配任务的 Grant 后，适配器才会调用已注册的本地证据核验 Agent，并继续写入审计事件、Artifact 和 Evidence Receipt。普通用户不配置端口、URL 或 Agent Card；以下脚本是运行时/测试入口，不是网络服务启动方式：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\.qianlima\scripts\invoke-personal-readonly-evidence-task.ps1" `
  -EnvelopePath ".\.qianlima\run-traces\<task-envelope>.json" `
  -GrantPath ".\.qianlima\run-traces\delegation-grants\<grant>.json" `
  -ExplicitStart
```

适配器拒绝缺少或不匹配的 Grant、过期/撤销 Grant、网络/写入/委派权限、其他工具，以及任何地址或远程派发字段。回归测试：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\.qianlima\scripts\test-personal-readonly-evidence-task.ps1"
```

生成本地 usage ledger 记录（默认会被 `.gitignore` 排除）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\.qianlima\scripts\new-usage-record.ps1" -RunId "demo-run" -TaskName "demo" -WorkflowId "knowledge_digest" -EstimatedCost 0.03 -BaselineCost 0.10 -SavingsSource "context_reduction" -TaskSuccess
```

生成用户可见的实时成本卡。脚本输出使用 ASCII，避免 Windows PowerShell 编码问题；中文展示格式见 `.qianlima/templates/realtime-cost-card_template.md`：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\.qianlima\scripts\new-cost-card.ps1" -EstimatedCost 0.03 -BaselineCost 0.10 -SavingsSource "context_reduction"
```

导出 Obsidian Git-safe Vault：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\.qianlima\scripts\export-obsidian-vault.ps1" -OutputRoot ".\obsidian-export"
```

为已确认的高风险动作生成本地 decision log：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\.qianlima\scripts\new-decision-log-entry.ps1" -RunId "demo-run" -Scenario "ad_ops" -WorkflowId "daily_ad_report" -ActionType "change_bid" -RiskLevel high -Recommendation "example" -ExpectedImpact "example" -ExpectedRisks "example" -SourceRefs "data:sample_ads_daily:daily_snapshot" -UserConfirmationRef "user-confirmation-example"
```

## 依赖

- **Agent 框架**：CodeWhale、Claude Code 或其他支持 YAML 治理文件的 Agent 系统
- **MCP 工具**：Sorftime MCP、Pangolinfo MCP
- **浏览器自动化**：Kimi WebBridge，可选，用于领星 ERP 数据提取
- **飞书**：lark-cli，可选，用于表格同步

## 版本历史

| 版本 | 日期 | 变更 |
|:--:|------|------|
| v2.8.0 | 2026-07-22 | 个人 Governed Loop：Builder/Checker 硬隔离、原始检查输出保留、最多 5 轮、同错/回归/无进展自动冻结和用户取消停止。 |
| v2.7.9 | 2026-07-21 | 个人学习管线：资源摘要、局部计划、显式 Grant 只读执行、验证收敛；默认无后台、无自动安装、无网络和无远程/集群执行。 |
| v2.7.8 | 2026-07-21 | 个人版本地 stdio 只读证据工具：唯一工具合同、任务匹配 Grant、过期/撤销/越权运行时拒绝、审计事件和 Evidence Receipt。无地址、端口、网络监听或业务写入。 |
| v2.7.7 | 2026-07-20 | 个人版渐进式治理：续问快速路径、任务相关记忆 Chunk、偏好版本化与回退、一键清除个人经验、受限 Skill 安装门禁。 |
| v2.7.3 | 2026-07-15 | Codex 体感提速：普通对话、L0/L1 快答和同主题续问不重复启动；新增单调用上下文装配、会话租约和 L4 启动门禁。 |
| v2.7.2 | 2026-07-14 | 跨平台启动：新增 macOS/Linux PowerShell 与 bash 入口及公开 CI 检查。 |
| v2.7.1 | 2026-07-13 | Agent Harness 运行时升级：L0-L4 分层启动、快速状态检查、预算/沙箱/状态机、命令安全 Hook、QianlimaEval、延迟观测、私有 Memory Cards、Maker/Checker 分工与状态化 EVR Loop；公开模板完成隐私清理。 |
| v2.6.6 | 2026-07-09 | 新增 Obsidian 本地知识库适配：Vault 策略、笔记模板、MOC 模板和 Git-safe 导出脚本 |
| v2.6.5 | 2026-07-09 | 新增 LinkAI Cloud 发布入口和 Agent Prompt 模板，限定为 Git-safe 知识库问答与多渠道入口 |
| v2.6.4 | 2026-07-09 | 新增通义灵码 / Qoder CN 专用入口：`QODER.md`、`LINGMA.md`，并同步启动提示 |
| v2.6.3 | 2026-07-09 | 标准化实时成本卡：新增成本卡模板和生成脚本，统一 Agent 输出字段 |
| v2.6.2 | 2026-07-09 | 实时成本卡和节约中心原则：usage ledger 增加基线成本、节约金额、节约率、成本状态和是否继续 |
| v2.6.1 | 2026-07-09 | 吸收 XPolicyLab 策略适配器思想；加入 COMA / Comattack 压缩攻击防御、评估门禁和高风险摘要拦截 |
| v2.6 | 2026-07-09 | 自然语言任务自动匹配：新增 natural-language-router、技能打分、置信度阈值、缺参追问和高风险确认 |
| v2.5.1 | 2026-07-09 | Agent 启动入口补丁：Codex、Claude Code、Manus、桌面端 Agent 简报 |
| v2.5 | 2026-07-09 | Git-safe 公开模板：中文 README、隐私边界、CI 校验、runtime gate、workflow 补齐 |
| v2.4 | 2026-07-08 | 公开模板强化：隐私边界、校验脚本、runtime gate、workflow 补齐 |
| v2.2 | 2026-07-08 | SOTA 落地：KV Cache / memgovern / nemo-skills / alembic / gdpo / marshal / celery |
| v2.1 | 2026-07-08 | Loop Engineering：SDR / EVR / PBV / EDA 嵌入 workflow |
| v2.0 | 2026-07-08 | Harness 核心：健康自检 / 进化改进 / 子代理编排 / Context 2.0 |
| v1.3 | 2026-07-08 | 基础治理：场景路由 / 风险规则 / 验证门禁 |

## 引用

- Lilian Weng. “Harness Engineering for Self-Improvement.” 2026.
- XPolicyLab/XPolicyLab. Policy adapter and server-client separation pattern.
- zsLiu2003/Comattack. COMA compression attack threat model.
- 机器之心 SOTA：loop-engineering / memgovern / nemo-skills / alembic / gdpo / marshal / celery / awesome-kv-cache-optimization

## 许可证

MIT
