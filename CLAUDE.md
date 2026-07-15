# CLAUDE.md — 千里马私有运营工作区

## 快速路径

- 普通对话、简单只读问题和同主题续问：直接回答，不运行启动脚本，不读取运营配置。
- 新的 L2/L3 业务任务：先给一句有效判断，再调用 `.qianlima/scripts/qianlima-context-fast.ps1` 一次完成缓存检查、必要启动和最小上下文装配；不要串行运行 status + startup。
- L4：改价、调竞价、调预算、采购、删除、覆盖、写回或发送外部消息，必须完整校验、原始数据复核和用户二次确认。

续问关键词包括：`继续`、`下一步`、`还有吗`、`展开第 N 点`、`再详细一点`、`接着做`。只要目标、数据源、风险和配置没有变化，续问不得触发脚本、重复读启动包或单独记账。

## 运行时规则

业务任务需要时读取 `.qianlima/CODEX_BOOT.md`，再按 task-card/workflow 加载最小文件。不要扫描整个工作区；高风险结论必须回读原始数据。删除、覆盖、格式化和递归移动前运行 `.qianlima/scripts/check-command-safety.ps1`。

真正完成的 workflow 才写 `.qianlima/usage-ledger/runs.jsonl`；普通对话和续问不是 workflow。未知 token、成本和耗时填 `0`，不得编造。

不要把私有 `work.ws`、数据源、报告、账本、绝对路径、凭据或业务记录复制到公开仓。
