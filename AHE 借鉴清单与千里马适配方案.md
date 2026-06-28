# AHE 借鉴清单与千里马适配方案

## 来源

参考仓库：

https://github.com/china-qijizhifeng/agentic-Harness-engineering

该仓库的方向是 Agentic Harness Engineering，重点在 coding-agent harness 的自动化演化。千里马计划的方向不同，主要面向大众工作场景、数据连接器、文件治理、运营自动化和个人/企业工作流。

因此，不直接照搬 AHE 的 coding-agent 结构，而是借鉴其中适合工作场景治理的机制。

## 适合借鉴的核心思想

### 1. Harness 不只是提示词，而是可演化系统

AHE 的关键价值在于把 Agent 外层 harness 当成可以评估、分析、改进的系统，而不是一次性写死的 prompt。

千里马适配：

- 每个 workflow 都要有定义文件
- 每次运行都要有 trace
- 每次失败都要能复盘
- 规则和模板可以持续改进
- 用户反馈能沉淀为下一轮执行策略

### 2. 三类可观测性

AHE 强调：

- 组件可观测
- 经验可观测
- 决策可观测

千里马适配为：

| AHE 思想 | 千里马版本 | 说明 |
|---|---|---|
| 组件可观测 | workflow 组件观测 | 每个工作流的数据源、模板、规则、输出、成本可追踪 |
| 经验可观测 | 工作经验观测 | 用户采纳了什么建议、哪些规则有效、哪些判断经常错 |
| 决策可观测 | 决策依据观测 | 每个建议必须能追溯到数据、规则和风险判断 |

### 3. Evaluate -> Analyze -> Improve 闭环

AHE 的自动演化可以抽象为：

```text
运行任务
  -> 评估结果
  -> 分析失败或低效原因
  -> 改进 harness
  -> 再运行
```

千里马适配为：

```text
运行 workflow
  -> 检查报告质量、数据来源、权限、成本
  -> 分析失败原因、用户修改、未采纳建议
  -> 更新规则、模板、数据源映射或确认策略
  -> 下一次自动使用新规则
```

### 4. 把失败变成改进资产

AHE 适合借鉴的一点是：失败不是只记录错误，而是进入后续改进循环。

千里马适配：

- 数据缺字段，要沉淀字段映射规则
- 报告格式用户不满意，要更新模板
- 建议不准确，要更新诊断规则
- 成本过高，要更新数据读取策略
- 多次需要确认同类动作，要沉淀用户偏好

### 5. 用配置文件管理系统行为

AHE 以配置为中心组织 agent/harness 行为。千里马也应该把行为显式写到文件里，而不是藏在对话里。

千里马适配：

- `work.ws`：工作状态
- `workflow-index.yaml`：工作流索引
- `data-sources.yaml`：数据源
- `file-registry.yaml`：文件调用
- `observability.yaml`：观测指标
- `evaluation-tasks.yaml`：评估任务
- `improvement-loop.yaml`：改进循环

## 不建议直接借鉴的部分

| AHE 内容 | 不直接采用的原因 |
|---|---|
| coding-agent 专用 harness | 千里马不是以编程为主 |
| SWE-bench 类评测方向 | 千里马需要工作流评测，不是代码补丁评测 |
| 自动修改 agent 代码 | 大众工作场景优先使用规则、模板、配置渐进改进 |
| 复杂研究型 pipeline | MVP 阶段要轻量，避免用户难理解 |

## 千里马新增骨架

为了吸收 AHE 的适合部分，新增三类配置：

1. `observability.yaml`
   - 记录 workflow 组件、经验、决策、成本和文件调用的观测指标。

2. `evaluation-tasks.yaml`
   - 定义每个 workflow 的评估任务，例如广告日报是否引用数据源、是否标记风险、是否记录成本。

3. `improvement-loop.yaml`
   - 定义从失败、用户反馈、成本异常到规则改进的流程。

## 适配后的千里马核心闭环

```text
工作状态 work.ws
  -> 数据连接 data-sources.yaml
  -> 文件调用 file-registry.yaml
  -> 工作流 workflow
  -> 执行日志 logs
  -> 成本台账 usage-ledger
  -> 评估任务 evaluation-tasks.yaml
  -> 改进循环 improvement-loop.yaml
  -> 更新规则、模板、字段映射和用户偏好
```

## 下一步

优先把 AHE 思想落地到广告日报 MVP：

1. 每次生成日报后跑一次 evaluation。
2. 如果缺少来源、字段、风险或成本记录，标记为未通过。
3. 如果用户修改报告，记录到 feedback。
4. 每周根据 feedback 更新模板和诊断规则。

