# 千里马计划 — 亚马逊运营 AI Agent Harness

> 版本: v2.7.0 | 2026-07-11

千里马计划是一个面向亚马逊卖家的 **AI Agent Harness 系统**。它不是另一个"关键词工具"或"广告管理面板"——它是 **Agent 治理层**，让 LLM 能可靠、安全、可追溯地执行亚马逊运营任务。

覆盖场景：广告运营 · 销量台账 · 关键词追踪 · 库存预警 · 利润复盘 · 选品分析 · Agent 自我进化。

---

## 核心理念

> "Harness 不是 prompt 模板——是运行时系统。
> 它观察自己、诊断问题、积累经验、并自我改进。"

设计灵感来自 [Lilian Weng — Harness Engineering for Self-Improvement (2026)](https://lilianweng.github.io/posts/2026-07-04-harness/)，融合了多个 SOTA 项目的工程思想。

---

## 架构总览

```
千里马 Harness v2.7.0
│
├── 🧭 场景智能路由           → 按场景精准加载，context 占用降低 40-60%
├── 🩺 健康自检               → 5 维度启动时自动诊断（数据新鲜度 / 注册表一致性 / 配置漂移 / 工作区完整性 / 隐私泄漏）
├── 🔁 Loop Engineering        → SDR / EVR / PBV / EDA 四层执行循环
├── 🧪 QianlimaEval            → 借鉴 MiniAppBench：Intent / Evidence / Dynamic / Cost / Risk 多维评分
├── 🧬 进化式改进             → 5 策略（fix / tune / A/B / extract / evolve）+ 记忆治理
├── 🧩 子代理编排             → 4 类型 + 4 模式 + 任务调度 + 资源限流
├── 📐 Context 2.0            → 动态上下文分配 + 智能压缩 + ConAct 记忆折叠
├── 📋 Skill 注册表           → 8 个技能标准化（trigger / scope / capability / quality_gate）
├── ⚡ KV Cache 优化          → 7 条缓存规则 + 前缀稳定性设计
├── 🗄️ 配置演化追踪           → forward / rollback / diff / audit 四维迁移
├── 🌍 轻量世界模型           → P3 研究借鉴层，暂不作为日常强制层
├── 🧠 EAT 四模块             → Smart Library + Meta Agents + Agent Bus + Firmware
└── 🔍 Exploration Engine     → Shadow Mode 安全探索，自动注册最优策略
```

---

## 快速开始

### 1. 环境准备

```powershell
# 克隆仓库
git clone <repo-url>
cd 千里马计划

# Python 依赖（可选，EAT 进化组件需要）
pip install -r requirements.txt
```

### 2. 配置隐私数据

```powershell
# 复制脱敏模板
copy .qianlima\data-sources.example.yaml .qianlima\data-sources.yaml
copy .qianlima\work.example.ws .qianlima\work.ws

# 编辑填入真实数据：
#   data-sources.yaml  → 飞书 spreadsheet_token、领星 URL 等
#   work.ws            → ASIN、成本、利润率、关键词列表等
```

### 3. 启动 Harness

```powershell
# 首次使用或配置变更时运行（生成工作区索引 + 健康自检）
powershell -NoProfile -ExecutionPolicy Bypass -File ".\start-qianlima.ps1"

# 或使用中文入口
powershell -NoProfile -ExecutionPolicy Bypass -File ".\启动千里马计划.ps1"
```

### macOS / Linux

安装 PowerShell 7 后使用同一套运行时：

```bash
brew install --cask powershell
bash start-qianlima.sh
```

详见 [MACOS.md](MACOS.md)。

### 4. 触发第一个任务

在 CodeWhale / Claude / 其他 Agent 框架中加载千里马后，直接说：

| 你说的话 | 触发的任务 |
|----------|-----------|
| "跑一下关键词排名" | `keyword_rank_scan` |
| "生成广告日报" | `daily_ad_report` |
| "竞品对比" | `competitor_comparison` |
| "算一下这个产品赚不赚钱" | `profit_check` |
| "帮我优化这个 Listing" | `listing_optimization` |
| "帮我判断这个品类能不能做" | `product_discovery` |

非简单任务完成后，可以追加运行质量评估：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\.qianlima\scripts\new-qianlima-eval-report.ps1" `
  -WorkflowId "product_discovery" `
  -ReportPath ".\reports\your-report.md" `
  -UserGoal "判断这个品类能不能做" `
  -EstimatedCostUsd 0.03 `
  -BaselineCostUsd 0.10 `
  -CostLimitUsd 0.20
```

---

## 文件结构

```
千里马计划/
├── README.md                          # ← 你正在看的文件
├── AGENTS.md                          # Agent 启动规则（任何 AI 助手必读）
├── AI_START_HERE.md                   # 人类友好的快速入口
├── start-qianlima.ps1                 # 启动脚本（生成索引 + 健康自检）
├── 启动千里马计划.ps1                  # 中文入口
├── requirements.txt                   # Python 依赖
│
├── .qianlima/                         # ⚙️ Harness 治理中枢
│   ├── WORKSPACE_INDEX.md             # 工作区索引（启动时自动生成）
│   ├── work.ws                        # ⚠️ 隐私 — 工作状态总索引
│   ├── data-sources.yaml              # ⚠️ 隐私 — 数据源配置
│   │
│   ├── risk-rules.yaml                # 风险规则（高风险操作需确认）
│   ├── context-policy.yaml            # 上下文策略 v2.0（含 ConAct 记忆折叠）
│   ├── model-adapters.yaml            # 模型适配 + KV Cache 优化
│   ├── meta-scenario-router.md        # 场景智能路由 v1.2
│   ├── workflow-index.yaml            # Workflow 索引 v2.2
│   │
│   ├── harness-health-check.yaml      # 健康自检（5 维度）
│   ├── loop-engineering.yaml          # Loop Engineering 框架
│   ├── improvement-loop.yaml          # 进化式反馈闭环 v3.0
│   ├── qianlima-eval.yaml             # QianlimaEval 多维评分配置
│   ├── subagent-orchestration.yaml    # 子代理编排
│   ├── evolutionary-workflow.yaml     # 进化式 Workflow
│   ├── skill-registry.yaml            # Skill 注册表（8 技能）
│   ├── alembic-migration.yaml         # 配置演化追踪
│   ├── world-model.yaml               # 轻量世界模型（P3 研究）
│   │
│   ├── task-cards/                    # 任务卡定义（8 张）
│   ├── workflows/                     # Workflow 定义（5 条）
│   ├── templates/                     # 报告模板（14 个）
│   ├── playbooks/                     # 操作手册（3 本）
│   ├── usage-ledger/                  # 用量账本
│   └── reports/                       # 产出报告
│
├── agent-components/                  # 🧬 EAT 自我进化引擎
│   ├── smart_library.py               # P0: 语义组件发现
│   ├── meta_agent.py                  # P1: 经验分析 / 自动进化
│   ├── agent_bus.py                   # P2: 多 Agent 协作通信
│   ├── firmware_loader.py             # P3: 行为边界约束
│   ├── exploration_engine.py          # 安全探索（Shadow Mode）
│   ├── evolve.py                      # 进化管道入口
│   ├── discover.py                    # 组件发现 CLI
│   └── qianlima_bridge.py             # 千里马同步桥接
│
├── context-summaries/                 # 上下文压缩摘要
├── memory/                            # 会话记忆
├── reports/                           # 历史报告
├── kw-records/                        # 关键词排名记录
└── working/                           # 临时工作文件
```

---

## Harness 治理体系

### 场景智能路由

Agent 根据用户意图自动匹配场景，只加载相关治理文件，避免 context 膨胀：

```
用户输入 → meta-scenario-router.md
              │
              ├─ "广告日报"     → ad_ops       → daily_ad_report + 广告模板
              ├─ "关键词排名"   → keyword_tracking → keyword_rank_scan + 排名模板
              ├─ "销量台账"     → sales_tracking → sales_ledger
              ├─ "库存预警"     → inventory_monitor → inventory_alert
              ├─ "利润复盘"     → profit_review → profit_check
              ├─ "竞品对比"     → product_selection → competitor_comparison
              ├─ "Listing优化"  → content_ops   → listing_optimization
              └─ "策略探索"     → agent_evolution → exploration_engine
```

### Loop Engineering 四层循环

| Loop | 全称 | 适用场景 | 核心逻辑 |
|------|------|---------|---------|
| **SDR** | Scan → Diagnose → Repair | 关键词排名扫描 | 发现异常→诊断根因→修复建议 |
| **EVR** | Execute → Verify → Refine | 广告日报生成 | 执行采集→交叉验证→修正优化 |
| **PBV** | Predict → Benchmark → Validate | 销量预测 / 库存预警 | 预测→对标→验证偏差 |
| **EDA** | Explore → Document → Apply | 策略探索 | 安全探索→记录结果→注册最优策略 |

### QianlimaEval 运行质量评估

QianlimaEval 借鉴 MiniAppBench / MiniAppEval 的 `Generate -> Compile -> Evaluate` 思路，但面向亚马逊运营任务：

| 评估维度 | 权重 | 作用 |
|---|---:|---|
| Intent Alignment | 0.25 | 判断是否真正理解用户目标和业务问题 |
| Evidence / Static Quality | 0.25 | 检查报告结构、来源、待验证项、敏感信息 |
| Dynamic Execution Quality | 0.25 | 检查 trace、工具结果、验证门禁和可恢复状态 |
| Cost Savings / Efficiency | 0.15 | 检查成本卡、模型选择、节约和上下文压缩 |
| Risk Control | 0.10 | 检查高风险动作是否确认、是否避免未授权写回 |

默认阈值：`0.80` 以上通过，`0.60-0.80` 需要复核，低于 `0.60` 阻断。检测到凭证、未确认写回、高风险动作未确认时直接阻断。

### 风险规则（强制执行）

| 操作 | 策略 |
|------|------|
| 修改广告竞价 | ⛔ 必须先获得用户确认 |
| 修改广告预算 | ⛔ 必须先获得用户确认 |
| 删除数据 | ⛔ 默认禁止 |
| 发送到群聊 | ⚠️ 需确认 |
| 写回外部系统 | ⚠️ 需确认 |
| 敏感数据（token/key/密码） | 🔒 脱敏或聚合 |

### Agent Firmware 硬约束

| Agent | 禁止操作 | 需审批 |
|-------|---------|--------|
| ad-optimizer | change_bid, change_budget, pause_campaign, create_campaign, delete_data | change_bid, change_budget |
| inventory-monitor | create_purchase_order, modify_inventory, change_pricing, modify_listing | create_purchase_order |
| keyword-tracker | modify_listing, change_advertising | — |
| listing-optimizer | publish_listing_changes, modify_pricing, change_advertising | publish_listing_changes |

---

## Agent 自我进化体系（EAT + EurekAgent）

> 基于 EAT (Evolving Agents Toolkit) + EurekAgent (arxiv 2606.13662)

### 四模块 + 探索引擎

```
┌─────────────────────────────────────────────────────┐
│                   Exploration Engine                 │
│          Shadow Mode 安全探索 · 自动注册最优策略       │
├──────────┬──────────┬──────────────┬────────────────┤
│  Smart   │  Meta    │  Agent Bus   │   Firmware     │
│ Library  │ Agents   │  多Agent协作  │   行为边界      │
│ 组件发现  │ 经验分析  │   通信总线    │   硬约束执行     │
├──────────┴──────────┴──────────────┴────────────────┤
│                  EverOS 经验记忆层                    │
└─────────────────────────────────────────────────────┘
```

### 进化管道

```
执行任务 → evolve.py log → EverOS 经验 → meta_agent analyze
                                              │
                                      技能缺口 / 进化候选
                                              │
                                       evolve.py evolve → 新组件
                                              │
                                       Smart Library 注册
                                              │
                                exploration_engine explore → 最优策略
```

---

## 工具链

| 工具 | 用途 |
|------|------|
| **Sorftime MCP** | 关键词排名 / 竞品数据（首选） |
| **Pangolinfo MCP** | 关键词排名 / 竞品数据（回退，site=amz_us） |
| **Kimi WebBridge** | 浏览器自动化（领星 ERP / Amazon SERP） |
| **lark-cli** | 飞书表格读写 / 同步 / 消息 |
| **EAT 组件** | Agent 自我进化（Smart Library / Meta Agents / Exploration） |

---

## 关键路径

| 路径 | 说明 |
|------|------|
| `./` | 千里马项目根目录 |
| `./.qianlima/` | 千里马治理目录 |
| `.qianlima\` | Harness 治理中枢 |
| `agent-components\` | EAT 自我进化引擎 |
| `reports\` | 产出报告 |
| `daily-summaries\` | 每日摘要 |
| `_scripts\` | 自动化脚本 |

---

## 隐私声明

⚠️ 本项目 **不包含任何** 真实运营数据。以下文件被 `.gitignore` 排除：

- `data-sources.yaml` — 飞书 token / 领星 URL
- `work.ws` — ASIN / 价格 / 利润 / 关键词
- `reports/` — 历史报告
- `kw-records/` — 关键词排名记录
- 所有运行时产物（日志、账本、反馈、健康报告）

请使用 `.example` 模板文件自行配置。

---

## 版本历史

| 版本 | 日期 | 变更 |
|:----:|------|------|
| v2.4 | 2026-07-08 | ConAct 记忆折叠 (MemGUI-Agent) + work.ws 刷新至 v2.4 |
| v2.3 | 2026-07-08 | 轻量世界模型 (world-model.yaml, P3 研究借鉴) |
| v2.2 | 2026-07-08 | SOTA 落地: KV Cache / memgovern / nemo-skills / alembic / gdpo / marshal / celery |
| v2.1 | 2026-07-08 | Loop Engineering: SDR / EVR / PBV / EDA 嵌入 workflow |
| v2.0 | 2026-07-08 | Harness 核心: 健康自检 / 进化改进 / 子代理编排 / Context 2.0 |
| v1.3 | 2026-07-08 | 基础治理: 场景路由 / 风险规则 / 验证门禁 |

---

## 依赖

- **Agent 框架**: CodeWhale / Claude Code / 支持 YAML 治理文件的 Agent 系统
- **MCP 工具**: Sorftime MCP, Pangolinfo MCP
- **浏览器自动化**: Kimi WebBridge（可选，用于领星 ERP 数据提取）
- **飞书**: lark-cli（可选，用于表格同步 / 消息通知）
- **Python 3.10+**: EAT 进化组件（可选）

---

## 引用

- [Lilian Weng — Harness Engineering for Self-Improvement (2026)](https://lilianweng.github.io/posts/2026-07-04-harness/)
- EurekAgent: Environment-Conditioned Curriculum for Agent Self-Improvement (arxiv 2606.13662)
- 机器之心 SOTA 系列: loop-engineering / memgovern / nemo-skills / alembic / gdpo / marshal / celery / awesome-kv-cache-optimization / Fast-LeWorldModel / MemGUI-Agent

---

## License

MIT
