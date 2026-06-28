# 千里马计划 · 文档索引

> 一套面向 AI Agent 的高可靠执行与工作治理系统。让 Agent 连接真实数据、理解工作状态、安全可靠地执行任务，并持续优化。

> **📢 公开版说明（Public Edition）**
> 这是用于开源/分享的去敏版本：飞书 token、sheet_id 已替换为占位符；`work.ws` 的真实产品、价格、库存、财务目标已模板化为示例；`inbox/reports/logs/usage-ledger/working` 等运行数据不随仓库提交（见 `.gitignore`）。
> 真实密钥与业务数据请放入 `.qianlima/secrets.local.yaml`（已被忽略，不会上传），模板见 `.qianlima/secrets.example.yaml`。

## 阅读顺序

| 顺序 | 文件 | 定位 | 读完能理解 |
|:---:|------|------|------|
| 1 | `Work Scenario Governance Spec 工作场景治理标准.md` | 🎯 治理中枢 | 整个系统怎么运转 — 时间、场景、workflow、权限、成本、跨场景联动 |
| 2 | `Data Connector Spec 数据连接器标准.md` | 🔌 数据接入 | 数据源怎么登记、授权、脱敏、校验、被 workflow 调用 |
| 3 | `Harness 千里马计划 MVP 数据上下文层与广告运营日报 Agent.md` | 🏗️ 系统架构 | 七层能力模型 + 广告日报 Agent 的完整设计（日报结构、指标计算） |
| 4 | `PWE-v2.0个人使用版-治理方案.md` | 📦 远期参考 | 代码项目管理方案。当前工作台无代码项目，以 `.qianlima/` 体系为准 |
| 5 | `AHE 借鉴清单与千里马适配方案.md` | 🔁 Harness 演化参考 | 组件可观测、经验可观测、决策可观测和改进闭环 |
| 6 | `AMZ-EVO 简单版融合说明.md` | 🧭 大众任务入口 | 如何把简单版亚马逊运营 harness 融合成普通人会用的任务卡 |
| 7 | `Knowledge Notebook Spec 知识库标准.md` | 📚 知识库 | 借鉴 NotebookLM：把文档打包成知识库，来源受限问答 + 逐条引用 + 简报/FAQ/时间线 |

## 实施入口

- **MVP 路线图**：见 `Work Scenario Governance Spec` §13（三阶段：单场景跑通 → 治理规则 → 多 workflow 扩展）
- **广告日报设计**：见 `Harness MVP` §日报结构
- **数据源登记**：见 `Data Connector Spec` §MVP 接入标准
- **大众任务入口**：见 `.qianlima/task-cards/`
- **亚马逊简单版流程**：见 `.qianlima/playbooks/amz-simple-playbook.yaml`

## 大众可直接使用的说法

- 我要做竞品对比
- 帮我优化这个 Listing
- 算一下这个产品赚不赚钱
- 跑一下这些关键词排名
- 帮我判断这个品类能不能做
- 把这几份 SOP 做成我的知识库，然后问它问题
- 基于这个知识库给我出一页简报 / 一版 FAQ / 一条时间线

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
| 工作场景治理标准 | `Work Scenario Govern