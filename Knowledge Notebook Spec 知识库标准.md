# Knowledge Notebook Spec 知识库标准

## 一句话定义

Knowledge Notebook Spec 是千里马计划的知识库标准。它规定个人或企业的非结构化文档（SOP、复盘、会议纪要、合同、竞品资料、规范文档）如何被打包成一个「知识库」（notebook），如何被 Agent 以**来源受限、逐条引用**的方式问答，并如何从中生成简报、FAQ、时间线等衍生产物——做到**只基于已登记的源回答，资料里没有就明说没有，绝不靠通用知识脑补**。

> **概念来源**：本标准借鉴 NotebookLM 的核心思想——以用户自己的源资料为唯一依据、答案逐句可追溯到源段落。千里马不照搬其产品形态，而是把「来源受限 + 行内引用 + 衍生产物」的内核接到已有的数据连接器和治理体系上。

> **基础依赖**：时间获取（用于时间线、归档命名、新鲜度）见 **Work Scenario Governance Spec · 基础维度：时间**。数据登记、权限、脱敏、访问日志复用 **Data Connector Spec**。

## 核心定位

知识库是结构化数据治理之外的**第二条腿**。

千里马原有体系围绕**结构化交易数据**（广告/销量/库存）→ workflow → 日报。知识库面向**非结构化文档知识**，回答的不是「昨天 ACoS 多少」，而是「我们 PD 期间的关键词巡检 SOP 是怎么规定的」「历史上断货踩过哪些坑」「这份合同的违约条款写了什么」。

它负责回答六个问题：

1. 这个知识库收录了哪些源文档？
2. 这些源覆盖哪些主题、哪个工作场景？
3. 用户的问题能不能在这些源里找到答案？
4. 答案的每一句话出自哪个文件的哪一段？
5. 哪些是源里明确写的，哪些是源里没有、不能回答的？
6. 能不能把整个知识库浓缩成简报、FAQ 或时间线？

一句话概括：

**Knowledge Notebook = 源文档登记 + 主题归集 + 来源受限问答 + 行内引用 + 反幻觉边界 + 衍生产物。**

## 与现有体系的关系（不重复造轮子）

知识库**复用**而非重建已有能力：

| 已有能力 | 知识库如何复用 |
|---|---|
| `data-sources.yaml` 的 `document` 类型 | 知识库的源就是 document 型数据源，沿用同一套登记/权限/脱敏标准 |
| `output_trace.must_cite_source` | 问答和衍生产物强制引用，直接用这条已有约束 |
| 访问日志、成本台账 | 每次问答按 Data Connector Spec 记录访问与 Token |
| AHE「决策可观测」 | 「每个建议要能追溯到证据」= 知识库的逐条引用，知识库把它做实 |
| work-hub「经验联动」 | 跨场景复用的「经验」终于有实体——一个可问答的知识库 |

知识库**新增**的部分只有三块：①把文档按主题打包成可问答的 notebook；②来源受限问答与反幻觉边界；③简报/FAQ/时间线等衍生产物。

## 面向大众用户的原则

- 用户用业务语言说「把这几份 SOP 当成我的运营知识库」，Agent 负责登记。
- 用户不需要懂向量、检索、分块这些技术词。
- 每个知识库都有看得懂的名字和用途说明。
- 答案默认带引用，用户能点回原文核对。
- 资料里没有的，Agent 明确说「资料里没有」，并可建议补充哪类源——不编。
- 知识库默认只读，不修改源文档。

用户可以这样说：

```text
把这几份 SOP 和踩坑日志做成我的运营知识库。
问一下：PD 期间关键词多久巡检一次？
基于这个知识库给我出一页简报。
把这个知识库里的常见问题整理成 FAQ。
这份合同里关于退货的条款是怎么写的？
```

## 1. notebook 概念与 notebooks.yaml

一个 **notebook（知识库）** 是一组围绕主题或场景的 `document` 源的集合。它是问答和衍生产物的作用域——Agent 回答时只看这个 notebook 绑定的源，不越界。

`notebooks.yaml` 是知识库注册表，建议位置 `.qianlima/notebooks.yaml`。

标准结构：

```yaml
notebooks:
  - notebook_id: amazon_ops_kb
    display_name: 亚马逊运营知识库
    purpose: 收录运营 SOP、踩坑日志、历史复盘，供随时问答和出简报
    scenarios: [ad_ops, keyword_tracking, inventory_monitor, profit_review]
    status: active                 # draft | active | archived
    grounding: strict              # strict=只用源；assisted=源优先+标注外部补充
    sources:                       # 引用 data-sources.yaml 里的 document 源
      - sop_standard
      - pitfalls_log
      - ops_dashboard
    default_citation_style: inline # inline 行内引用 | footnote 脚注
    derived_artifacts: [briefing, faq, timeline]
    permissions:
      access_level: suggest_only   # 知识库只读、只答、不改源
      forbidden_operations: [modify_source, delete_source, external_send]
    output_trace:
      must_cite_source: true
```

维护原则：

- 一个 notebook 至少绑定一个 `document` 源。
- 源的增删通过对话确认后更新 `notebooks.yaml`，不要求用户手填。
- `grounding: strict` 是默认值——只用源。只有用户显式同意，才允许 `assisted`（源优先、外部补充必须标注「非源内容」）。

## 2. 源类型

知识库的源是 Data Connector Spec 里的 `document` 型数据源，常见子类：

| 子类 | 示例 |
|---|---|
| 规范/制度 | SOP、操作手册、治理规范 |
| 经验/复盘 | 踩坑日志、周/月复盘、事故记录 |
| 业务资料 | 竞品资料、市场调研、产品文档 |
| 法务/财务 | 合同、对账单、政策文件 |
| 会议/沟通 | 会议纪要、决策记录 |

每个源沿用 Data Connector Spec 的登记字段（display_name / business_purpose / permissions / privacy / output_trace），额外建议补充供检索用的字段：

```yaml
document_meta:
  doc_id: sop_standard
  title: SOP 标准操作流程
  sections_indexed: true        # 是否已按标题/段落建立锚点
  anchor_style: heading         # heading=用标题定位 | line=用行号定位
  last_indexed: "2026-06-23"
```

## 3. 知识库生命周期

```text
collected -> registered -> indexed -> active -> stale -> archived
```

| 状态 | 说明 |
|---|---|
| `collected` | 用户指定了要纳入的文档，未登记 |
| `registered` | 源已写入 data-sources.yaml，notebook 已建 |
| `indexed` | 已按标题/段落建立可引用的锚点 |
| `active` | 可被问答和衍生产物使用 |
| `stale` | 源文档已更新但未重新索引，引用可能失效 |
| `archived` | 不再使用，仅保留记录 |

源文档变更后 notebook 进入 `stale`，下次问答前必须提示用户「资料已更新，需要重新索引」，不能用旧锚点静默作答。

## 4. 来源受限问答（knowledge_qa）

### 4.1 回答规则（反幻觉边界）

这是本标准的核心。问答必须遵守：

1. **只用源**：答案只能来自该 notebook 绑定的源（`grounding: strict`）。
2. **逐条引用**：每一条结论后附引用，指向源文件 + 段落锚点。
3. **无源即拒答**：源里找不到依据时，回答「资料里没有相关内容」，可建议补充哪类源，**不得用通用知识填补**。
4. **区分事实与推断**：源里明写的标为事实；需要跨段落推断的标「（基于…推断）」。
5. **冲突要并列**：多个源说法不一致时，并列展示并标注各自来源，不替用户裁决。
6. **不外推**：不把源里某产品的结论套到源没覆盖的产品上。

### 4.2 引用格式

行内引用（默认）：

```text
PD 期间关键词巡检频率从日常 2 次提升到每 30 分钟一轮。〔来源：SOP-领星每日巡检框架.md · PD 巡检节奏〕
```

脚注式（长答案可选）：

```text
PD 期间巡检频率提升到每 30 分钟一轮 [1]。

[1] SOP-领星每日巡检框架.md · 「PD 巡检节奏」段落
```

引用必须能定位到段落（标题锚点或行号），不能只写文件名。

### 4.3 问答 workflow 标准结构

对齐 Governance Spec §3.2，定义见 `.qianlima/workflows/knowledge_qa.wf.yaml`，要点：

```yaml
workflow:
  id: knowledge_qa
  name: 知识库来源受限问答
  inputs:
    notebook_id: { required: true }
    question:    { required: true }
  execution:
    steps:
      - retrieve_passages      # 在 notebook 源内检索相关段落
      - check_coverage         # 判断是否有足够源覆盖问题
      - compose_grounded_answer# 仅用检索到的段落作答，逐条挂引用
      - verify_citations       # 审计每条结论是否都有有效引用
  quality_gates:
    - every_claim_has_citation # 每条结论都有引用
    - no_uncited_external_fact # 没有无引用的外部事实
    - refuse_when_uncovered    # 无覆盖时正确拒答
  permissions:
    allowed: [read_sources, generate_report]
    forbidden: [modify_source, delete_source, external_send]
```

## 5. 衍生产物

在同一个 notebook 上，除问答外可生成以下产物（均强制引用、均不改源）。音频概览（Audio Overview）需 TTS，列为**远期**，不进 MVP。

| 产物 | 用途 | 模板 |
|---|---|---|
| 简报 briefing | 把知识库浓缩成一页要点 | `templates/briefing_template.md` |
| FAQ | 从源里抽常见问题与解答 | `templates/faq_template.md` |
| 时间线 timeline | 把源里的事件按时间排序 | `templates/timeline_template.md` |
| 问答报告 | 单次问答的结构化留档 | `templates/knowledge-qa_template.md` |
| 音频概览（远期） | 播客式音频总结，需 TTS | — |

衍生产物同样遵守 §4.1：简报里每个要点要可追溯到源，FAQ 每条答案带引用，时间线每个事件标出处。

## 6. 权限与隐私

- 知识库默认 `suggest_only`：可读、可答、可出产物，**不能修改或删除源文档**。
- 敏感字段（合同金额、客户联系方式、薪资等）沿用 Data Connector Spec 脱敏规则；问答命中敏感内容时按脱敏后呈现，原文调阅需确认。
- 衍生产物外发（发群/发邮件）属高风险，按 risk-rules.yaml 需单次确认。
- 每次问答记录访问日志（读了哪些源、哪些段落、是否命中敏感字段）。

## 7. 质量与验收标准

### 7.1 问答质量

每次问答必须满足：

1. **引用覆盖**：每条结论都有可定位的引用。
2. **正确拒答**：源未覆盖的问题，明确说「资料里没有」，不编造。
3. **来源真实**：引用的文件和段落确实存在且包含该内容（审计抽查）。
4. **冲突透明**：源之间矛盾时并列标注，不私自取舍。
5. **脱敏合规**：敏感内容按规则脱敏。

### 7.2 评估任务

新增评估任务（见 `evaluation-tasks.yaml`）：

- `citation_coverage`：随机抽 5 条结论，每条都能在源里定位 → 通过。
- `grounded_refusal`：构造源里没有的问题，Agent 应拒答而非编造 → 通过。
- `no_hallucinated_source`：引用的文件/段落必须真实存在 → 通过。

### 7.3 验收清单（notebook 从 draft 升级到 active）

- [ ] 至少绑定一个已登记的 document 源
- [ ] 源已建立段落锚点（indexed）
- [ ] 试问 5 个问题，引用均可定位
- [ ] 至少 1 个「源里没有」的问题被正确拒答
- [ ] 权限为只读/suggest_only，无修改源能力
- [ ] 访问日志和成本记录正常

## 8. 和其他治理文件的关系

```text
notebooks.yaml                    ← 本 spec 定义
  记录有哪些知识库、收录哪些源、用什么引用风格

data-sources.yaml                 ← 知识库的源（document 类型）登记于此
file-registry.yaml                ← 源文件与衍生产物登记于此
workflows/knowledge_qa.wf.yaml    ← 来源受限问答的执行定义
templates/                        ← 问答/简报/FAQ/时间线模板
evaluation-tasks.yaml             ← 引用覆盖、正确拒答、来源真实性评估
logs/ + usage-ledger/             ← 访问日志与成本，复用现有标准
```

## 9. MVP 落地清单

### 第一阶段：单知识库跑通

- [ ] 选定 3-5 份文档，登记为 document 源
- [ ] 建第一个 notebook（`grounding: strict`）
- [ ] 建立段落锚点
- [ ] 跑通 `knowledge_qa`：问 5 个问题，验证引用可定位
- [ ] 验证「源里没有」的问题被正确拒答

### 第二阶段：衍生产物

- [ ] 出一页简报
- [ ] 抽一版 FAQ
- [ ] 排一条时间线
- [ ] 衍生产物逐条可追溯到源

### 第三阶段：多知识库与跨场景

- [ ] 建第二个 notebook（如运营 vs 设计）
- [ ] 接入 work-hub「经验联动」：某场景沉淀的经验进知识库供其他场景问答
- [ ] 音频概览（远期，需 TTS）评估

### MVP 通过标准

1. 至少一个 notebook 能基于源回答问题，每条结论带可定位引用
2. 源未覆盖的问题被正确拒答，无编造
3. 引用的文件/段落经抽查真实存在
4. 至少能生成简报、FAQ、时间线各一份，且均可追溯
5. 知识库只读，从未修改过源文档
6. 每次问答有访问日志和成本记录
