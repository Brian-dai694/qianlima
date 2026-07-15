# LINKAI.md — LinkAI Cloud 发布入口

适用于把千里马发布成外部问答 Agent、知识库 Agent 或多渠道运营助手。

## 定位

LinkAI 适合做千里马的发布层和知识库问答层，不作为真实业务写回执行层。

推荐用途：

- 面向团队的千里马知识库问答
- 网页 / Slack / Discord / Telegram / WhatsApp 等渠道入口
- 基于脱敏文档的任务路由说明
- 展示成本状态卡、风险提示和下一步建议

不推荐用途：

- 直接写回 ERP、广告后台、飞书真实业务表
- 保存 API key、token、cookie、真实账号或本地路径
- 上传真实 ASIN 成本台账、订单、客户信息、未脱敏报告
- 自动执行调价、调预算、采购、删除或外部发送

## 知识库上传清单

只上传 Git-safe 内容：

```text
README.md
DESKTOP_AGENT_BRIEF.md
LINKAI.md
.qianlima/README.md
.qianlima/WORKSPACE_INDEX.md
.qianlima/workflow-index.yaml
.qianlima/risk-rules.yaml
.qianlima/context-policy.yaml
.qianlima/natural-language-router.yaml
.qianlima/rules/cost-savings-principle.md
.qianlima/rules/compression-attack-defense.md
.qianlima/templates/realtime-cost-card_template.md
.qianlima/templates/linkai-agent-prompt_template.md
.qianlima/task-cards/
.qianlima/workflows/
.qianlima/templates/
```

不要上传：

```text
.qianlima/work.ws
.qianlima/data-sources.yaml
.qianlima/usage-ledger/
.qianlima/logs/
.qianlima/reports/
.qianlima/run-traces/
screenshots/
任何真实 token、账号、ASIN、SKU、客户、成本、订单或本地路径
```

## Agent Prompt

使用模板：

```text
.qianlima/templates/linkai-agent-prompt_template.md
```

## 工作流建议

LinkAI workflow 建议分 5 步：

1. 意图识别：判断用户是问规则、问任务路由、问成本、问风险，还是要求执行。
2. 知识库检索：只检索 Git-safe 知识库。
3. 风险判定：涉及真实写回、高风险动作或私有数据时拒绝执行，只给安全建议。
4. 成本卡输出：非简单任务必须显示成本状态卡。
5. 下一步建议：给出需要在私有工作区执行的命令或需要用户确认的事项。

## 输出要求

每次回答优先输出：

- 当前场景
- 数据来源
- 风险等级
- 成本状态卡
- 可执行下一步
- LinkAI 不能执行的事项
