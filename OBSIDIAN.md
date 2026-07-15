# OBSIDIAN.md — Obsidian 本地知识库入口

适用于把千里马沉淀成本地 Markdown Vault。Obsidian 是知识沉淀层，不是业务写回执行层。

## 定位

Obsidian 适合做：

- 本地知识库
- 工作流地图
- 任务卡索引
- 成本节约记录
- 风险规则沉淀
- 报告摘要和决策复盘

Obsidian 不适合做：

- 真实 ERP 写回
- 广告预算或竞价修改
- API token 保存
- 未脱敏业务数据同步到公开 Vault

## Vault 分层

必须分离两个 Vault：

```text
千里马-git-safe-vault   # 公开模板、规则、脱敏示例
千里马-private-vault    # 私有 ASIN、成本、报告、决策日志
```

`千里马-git-safe-vault` 可以由公开仓导出。`千里马-private-vault` 只能在私有工作区本地维护，不推送 GitHub。

## 推荐目录

```text
00-入口/
01-工作流/
02-任务卡/
03-规则/
04-成本节约/
05-风险与确认/
06-Agent入口/
07-报告摘要/
08-决策日志/
99-归档/
```

## 必读模板

```text
.qianlima/templates/obsidian-note_template.md
.qianlima/templates/obsidian-moc_template.md
.qianlima/rules/obsidian-vault-policy.md
```

## 导出

生成 Git-safe Vault：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\.qianlima\scripts\export-obsidian-vault.ps1" -OutputRoot ".\obsidian-export"
```

导出脚本只复制公开安全文件，不复制 `work.ws`、`data-sources.yaml`、usage ledger、报告、日志、截图或本地路径。

## 输出要求

任何 Agent 维护 Obsidian Vault 时，必须说明：

- 导出目标
- 是否 Git-safe
- 私有数据是否排除
- 成本卡是否保留
- 待人工确认项
