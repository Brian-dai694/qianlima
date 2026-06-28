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

## 大众使用入口

普通用户优先使用 `task-cards/`，不用直接编辑 workflow。

可以直接这样说：

- 我要做竞品对比
- 帮我优化这个 Listing
- 算一下这个产品赚不赚钱
- 跑一下这些关键词排名
- 帮我判断这个品类能不能做

## 借鉴 AHE 的三项能力

- 组件可观测：每个 workflow 的数据源、模板、规则、输出和成本都能追踪。
- 经验可观测：用户采纳、拒绝、修改过的建议会进入反馈记录。
- 决策可观测：每条建议都要能追溯到数据来源、规则和风险等级。
