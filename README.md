# 千里马— 亚马逊运营 AI Agent Harness
# 版本: v2.4 | 2026-07-08

千里马计划是一个面向亚马逊卖家的 AI Agent Harness 系统。它不是另一个"关键词工具"或"广告管理面板"——它是 **Agent 治理层**，让 LLM 能可靠、安全、可追溯地执行亚马逊运营任务。

## 核心理念

> "Harness 不是 prompt 模板——是运行时系统。
> 它观察自己、诊断问题、积累经验、并自我改进。"

基于 [Lilian Weng — Harness Engineering for Self-Improvement (2026)](https://lilianweng.github.io/posts/2026-07-04-harness/) 和多个 SOTA 项目的设计理念。

## 架构

```
千里马 Harness v2.2
├── 场景智能路由    → 按场景精准加载，context 占用降低 40-60%
├── 健康自检        → 5 维度启动时自动诊断
├── Loop Engineering → SDR/EVR/PBV/EDA 四层执行循环
├── 进化式改进      → 5 策略（fix/tune/A/B/extract/evolve）+ 记忆治理
├── 子代理编排      → 4 类型 + 4 模式 + 任务调度 + 资源限流
├── Context 2.0     → 动态上下文分配 + 智能压缩 + 实时监控
├── Skill 注册表    → 8 个技能标准化（trigger/scope/capability/quality_gate）
├── KV Cache 优化   → 7 条缓存规则 + 前缀稳定性设计
└── 配置演化追踪    → forward/rollback/diff/audit 四维迁移
```

## 快速开始

### 1. 克隆 + 安装依赖

```bash
git clone <repo-url>
cd qianlima
```

### 2. 配置隐私数据

```bash
# 复制脱敏模板
cp .qianlima/data-sources.example.yaml .qianlima/data-sources.yaml
cp .qianlima/work.example.ws .qianlima/work.ws

# 编辑填入你的真实数据
# data-sources.yaml: 飞书 spreadsheet_token、领星 URL 等
# work.ws: ASIN、成本、利润率、关键词等
```

### 3. 初始化工作区

```powershell
# Windows
powershell -NoProfile -ExecutionPolicy Bypass -File ".\start-qianlima.ps1"
```

### 4. 触发第一个任务

在 CodeWhale / Claude / 其他 Agent 框架中加载千里马后，直接说：

- "跑一下关键词排名" → `keyword_rank_scan`
- "生成广告日报" → `daily_ad_report`
- "竞品对比" → `competitor_comparison`
- "算利润" → `profit_check`

## 文件结构

```
.qianlima/
├── work.ws                      # ⚠️ 隐私 — 工作状态
├── data-sources.yaml            # ⚠️ 隐私 — 数据源配置
├── risk-rules.yaml              # 风险规则
├── context-policy.yaml          # 上下文策略 (v2.0)
├── model-adapters.yaml          # 模型适配 + KV Cache 优化
├── meta-scenario-router.md      # 场景智能路由 (v1.2)
├── workflow-index.yaml          # Workflow 索引 (v2.1)
├── improvement-loop.yaml        # 进化式反馈闭环 (v3.0)
├── harness-health-check.yaml    # 健康自检
├── loop-engineering.yaml        # Loop Engineering 框架
├── subagent-orchestration.yaml  # 子代理编排
├── evolutionary-workflow.yaml   # 进化式 Workflow
├── skill-registry.yaml          # Skill 注册表
├── task-cards/                  # 任务卡定义
├── workflows/                   # Workflow 定义
├── templates/                   # 报告模板
└── playbooks/                   # 操作手册
```

## 隐私声明

⚠️ 本项目**不包含任何**真实运营数据。以下文件被 `.gitignore` 排除：

- `data-sources.yaml` — 飞书 token
- `work.ws` — ASIN/价格/利润
- `reports/` — 历史报告
- `kw-records/` — 关键词排名记录
- 所有运行时产物（日志、账本、反馈）

请使用 `.example` 模板文件自行配置。

## 依赖

- **Agent 框架**: CodeWhale / Claude Code / 支持 YAML 治理文件的 Agent 系统
- **MCP 工具**: Sorftime MCP, Pangolinfo MCP
- **浏览器自动化**: Kimi WebBridge（可选，用于领星 ERP 数据提取）
- **飞书**: lark-cli（可选，用于表格同步）

## 版本历史

| 版本 | 日期 | 变更 |
|:--:|------|------|
| v2.2 | 2026-07-08 | SOTA 落地: KV Cache / memgovern / nemo-skills / alembic / gdpo / marshal / celery |
| v2.1 | 2026-07-08 | Loop Engineering: SDR/EVR/PBV/EDA 嵌入 workflow |
| v2.0 | 2026-07-08 | Harness 核心: 健康自检 / 进化改进 / 子代理编排 / Context 2.0 |
| v1.3 | 2026-07-08 | 基础治理: 场景路由 / 风险规则 / 验证门禁 |

## 引用

- Lilian Weng. "Harness Engineering for Self-Improvement." 2026.
- 机器之心 SOTA: loop-engineering / memgovern / nemo-skills / alembic / gdpo / marshal / celery / awesome-kv-cache-optimization

## License

MIT
