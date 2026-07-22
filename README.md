# 北极星企业版 — 可信 Agent 治理控制平面

[中文](README.md) · [English](README.en.md)

[![CI](https://github.com/Brian-dai694/beijixing/actions/workflows/qianlima-verify.yml/badge.svg)](https://github.com/Brian-dai694/beijixing/actions/workflows/qianlima-verify.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-v2.7.9-blue.svg)](CHANGELOG.md)
[![PowerShell](https://img.shields.io/badge/PowerShell-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)

> 版本: v2.7.9 | 2026-07-21 · 变更历史见 [CHANGELOG.md](CHANGELOG.md)

> 当前版本：v2.7.9 · 企业版配置版本：0.1.0 · 2026-07-22

千里马计划是一个面向亚马逊卖家的 AI Agent Harness 系统；北极星企业版是其面向企业 Agent 的可信治理控制平面。千里马负责业务工作流、证据与结果验证，北极星负责身份、最小授权、预算、审计和撤销。v2.7.9 增加个人版渐进式治理、任务相关记忆选择、显式本地只读执行、Execution Plan 与 EVR 验证闭环。

## 北极星协议

> 任何接入的 Agent，都必须经过准入、最小授权、证据核验、预算约束、审计与可撤销控制。

本项目借鉴了 [Lilian Weng — Harness Engineering for Self-Improvement (2026)](https://lilianweng.github.io/posts/2026-07-04-harness/) 以及多个 SOTA 项目的设计理念。v2.7.8 延续分层启动、运行时策略、命令安全、评估、观测、记忆卡、子代理分工与状态化 Loop 的公开安全模板。
硬边界：

- Agent Card 只是能力声明，不是权限。
- API 所有权不代表企业数据访问权。
- 安装 Agent 不代表获得 MCP 或业务写入权。
- 员工 Agent 只能使用任务级、短时、可撤销的 Grant。
- 上传、发送、删除和业务系统写入按企业 L4 治理。
- 生产规则改进只能生成候选，必须经过回放、仿真、独立核验和人工晋升。

## 企业架构

```text
千里马 Harness v2.7.9
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
└── 个人学习管线      → 资源摘要、局部提案、只读执行和收敛验证

企业部署的控制面与执行面关系：
老板 / 业务负责人 / 员工 / IT 安全管理员
                    |
             北极星治理 Broker
     ┌──────────────┼──────────────┐
     |              |              |
  身份与组织      策略与预算      审批与审计
     |              |              |
     └──────────────┼──────────────┘
                    |
          本机 Connector + 沙箱 Runner
                    |
       Codex / Claude Code / CodeWhale / 其他 Agent
                    |
       MCP / Skills / 文件 / ERP / 业务系统
```

北极星是控制平面；Agent 是执行平面；MCP 和 Skills 是工具平面。默认禁止 Agent-to-Agent 直连，所有二次委派都必须回到 Broker 重新授权。

## 四种部署模式

企业只需回答两个问题：是否统一购买 API，是否要求统一 Agent。

| 模式 | API | Agent | 默认治理 |
|---|---|---|---|
| E1 | 企业统一 | 企业统一 | 标准化程度最高 |
| E2 | 企业统一 | 员工从批准名单选择 | 默认推荐 |
| E3 | 员工或部门自带 | 企业统一 | BYOK，仅保存密钥引用 |
| E4 | 员工或部门自带 | 员工自选 | 默认 T1，验收后逐步授权 |

选择模式不会自动授予内部数据、MCP、网络或执行权限。

## 企业 L0-L4

| 等级 | 企业含义 | 典型动作 |
|---|---|---|
| L0 | 无企业数据的普通交流 | 解释、公开知识问答 |
| L1 | 公开或低敏只读分析 | 公开资料研究、草稿 |
| L2 | 部门内部只读任务 | 脱敏数据分析、报告生成 |
| L3 | 跨系统或受控内部协作 | 受控 MCP、跨部门引用 |
| L4 | 产生外部或业务状态变化 | 上传、发送、删除、改价、预算、采购、ERP 写入 |

L4 不等于全部交给老板逐条审批。系统按业务责任人、金额阈值、可逆性和批量授权路由；重大治理变更才要求老板或双人确认。

## 组织与员工

企业版提供四种新手角色：

- 老板：查看结果、重大风险和治理决策，不承担日常逐条审批。
- 业务负责人：管理项目、员工范围、MCP 准入和异常处理。
- 员工：用自然语言发起任务，只看到与当前工作相关的权限和结果。
- IT/安全管理员：管理身份、设备、Runner、密钥引用和安全事件，不读取无关业务内容。

员工生命周期覆盖入职、调岗、停职、离职和紧急隔离。调岗执行“先撤销、后授权”，员工记录和审计事件不可物理删除。

## MCP 与业务能力

企业版预留通用 MCP 平台，不绑定单一厂商，覆盖 ERP、财务、税务、海关、物流、库存、广告、市场研究、协作平台和文件系统等能力。

员工 Agent 经业务负责人批准后，可以通过本机 Connector 使用短时 MCP 会话；Connector 仍会逐次检查员工、设备、Agent 版本、任务、数据范围、预算和 Grant 状态。

当前领星、税务、海关及其他 MCP 均为接口合同与机械门禁，未在公开仓中配置真实端点、凭据或业务写入权限。

## 模型协作

模型融合不是多个模型聊天，而是受治理的证据协作：L0-L2 默认单模型，L3 才允许独立候选与证据核验，L4 只能生成候选并进入人工确认。模型档案和 Fusion Plan 见 `.qianlima/model-portfolio.yaml` 与 `.qianlima/fusion-plan-schema.yaml`。

## 业务成果

企业版覆盖选品上架、采购、物流履约、库存、流量转化、广告、活动、售后、清货与复盘，并支持：

- 日报、周报、月报、季报和年报。
- 月度、季度和年度计划。
- 日、周、月、季、年度利润口径。
- Listing 利润、标题、主图、五点和长描述成果包。
- 业务端、成果端、失败端、核心问题端和处理端五视图。
- 踩坑日志、改进候选、回放、仿真和人工晋升的复利系统。

## 快速开始

### 1. 克隆

```bash
git clone https://github.com/Brian-dai694/beijixing.git
cd beijixing
```

### 2. 选择 E1-E4

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File '.\enterprise 企业版\select-enterprise-deployment-mode.ps1'
```

### 3. 创建组织配置

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File '.\enterprise 企业版\new-enterprise-organization.ps1'
```

私有组织配置只写入 `.qianlima/local-data/enterprise/`，不会进入 Git。

### 4. 检查企业运行环境

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File '.\enterprise 企业版\test-enterprise-environment.ps1' -PassThru
```

企业版默认要求批准的隔离 Runner。缺少 Docker、Linux 容器后端、批准镜像或虚拟化能力时会返回 `blocked`，不会降级为不受控执行。

### 5. 启动企业版

Windows：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File '.\enterprise 企业版\start-enterprise.ps1'
```

macOS/Linux：

```bash
bash 'enterprise 企业版/start-enterprise.sh'
```

完整说明见 [企业版 README](enterprise%20企业版/README.md) 和 [分层使用说明书](enterprise%20企业版/企业版分层使用说明书.md)。

## 当前成熟度

| 范围 | 状态 |
|---|---|
| 企业治理合同 | 已实现并有离线回归 |
| E1-E4 部署模式 | 已实现 |
| 组织、员工和 L0-L4 | 已实现 |
| MCP/领星接口 | 已预留，默认禁用 |
| 真实企业身份与 SSO | 需要部署配置 |
| 真实沙箱 Runner | 需要 Docker/批准镜像与 Attestation |
| ERP、税务、海关写入 | 未在公开仓启用 |

部署就绪不等于执行授权。任何真实业务写入仍需任务级 Grant、审批、预检快照、审计和回滚条件。

## 验证

GitHub Actions 在 Windows 和 macOS 验证共享 Harness，并在 Windows 运行全部企业版离线回归。环境部署检查不会在公共 CI 中尝试安装 Docker 或获取企业凭据。

本地运行企业回归：

```powershell
$tests = Get-ChildItem -LiteralPath '.\enterprise 企业版' -Filter 'test-*.ps1' -File |
  Where-Object { $_.Name -ne 'test-enterprise-environment.ps1' }
foreach ($test in $tests) {
  powershell -NoProfile -ExecutionPolicy Bypass -File $test.FullName -PassThru
  if ($LASTEXITCODE -ne 0) { throw "Failed: $($test.Name)" }
}
```

## 主 Harness

企业版是 Overlay，不复制或修改主 Harness。内部仍复用 `.qianlima/`、`start-qianlima.ps1`、AGENTS/Claude/其他 Agent 入口和既有安全门。主 Harness 的开发说明见 [.qianlima/README.md](.qianlima/README.md)。

## 隐私与安全

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
公开仓只允许脱敏模板。禁止提交 API Key、Token、客户数据、账号信息、真实成本、业务导出、截图、运行日志、审计账本和本机绝对路径。凭据只能使用 Secret Reference，由操作系统或批准的密钥管理器保存。

## 许可证

MIT
