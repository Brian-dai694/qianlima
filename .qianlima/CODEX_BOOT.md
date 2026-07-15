# CODEX_BOOT — 千里马私有工作区短启动协议

你现在在千里马私有运营工作区。这里可以包含真实 `work.ws`、`data-sources.yaml`、业务记录和本地报告；不要把这些内容复制到 Git-safe 公开仓。

启动顺序：
1. 先判定 L0-L4。L0 普通聊天直接回答，不运行任何千里马脚本。
2. 明确低风险 L1 且不需要文件、外部数据或写回时直接回答，不运行脚本；需要本地规则或工具时，再单次运行 `.qianlima/scripts/qianlima-context-fast.ps1 -TaskText "..." -ContextLevel L1 -SessionId "<host-provided-thread-id>" -AsJson`。L2-L3 先发有效状态更新，再运行该装配器。未提供 SessionId 时不会复用租约。
3. L2/L3 将本次 task-card、workflow 和 template 的相对路径传给 `-RelevantPath`（用分号分隔），并使用 `-AutoStart`，一次调用完成缓存检查、必要启动和上下文装配；若返回 `startup_completed: true`，不得再次运行启动脚本。
4. L4 或规则/目录变更时运行 `powershell -NoProfile -ExecutionPolicy Bypass -File ".\start-qianlima.ps1" -Force`，再读取完整启动包和原始数据。

L0-L4 加载规则：
- L0 普通聊天、简单事实：直接答，不加载运营文件。
- L1 明确低风险任务：只读本文件和 `codex-router.json`。
- L2 本地结构化分析：再读对应 task-card、workflow、template。
- L3 多来源或外部数据分析：先输出状态卡和初步判断，再按需取证。
- L4 改价、竞价、预算、采购、删除、写回：回读风险规则和原始数据，二次确认后才执行。

任务路由：
- 跑排名 / 卡位 / 关键词 → `keyword_rank_scan` 或 `keyword_monitoring`
- 广告日报 / 广告花费 → `daily_ad_report`
- 调竞价 / 调预算 → 先亮假设，再走高风险确认
- 算利润 / 赚不赚钱 → `profit_check`
- 优化 Listing / 标题五点 → `listing_optimization`
- 竞品对比 / 对比 ASIN → `competitor_comparison`
- 选品 / 品类能不能做 → `product_discovery`
- 整理资料 / 总结文档 → `knowledge_digest`

新 L2/L3 业务任务开始时输出状态卡；L0、L1 和同主题续问不输出启动状态卡，不运行脚本：
- 工作区：私有运营
- 当前场景：___
- 已加载来源：___
- 将使用 workflow：___
- 高风险/待验证：___

交互规则：L2-L4 的第一条状态更新不等待脚本、文件或工具结果；L1 的后续追问可在同一显式 SessionId 的 30 分钟租约内复用短启动包。配置变更、路由歧义、跨域和 L4 请求立即失效租约。

续问短路：`继续`、`还有吗`、`展开第 N 点`、`再详细一点`、`接着做`、`下一步`默认继承当前对话的任务、路由和证据状态，不运行任何启动或状态脚本；只有目标、数据源、风险等级或配置发生变化时重新路由。

硬规则：
- 高风险动作：改价、调竞价、调预算、采购、删除、写回外部系统，必须二次确认。
- 结论必须标注数据来源和待验证项。
- 长文件先摘要，关键决策前重新读取源文件。
- 每个 workflow 完成前必须调用 `.qianlima/scripts/record-qianlima-usage.ps1` 追加到 `.qianlima/usage-ledger/runs.jsonl`；没有成功入账的 workflow 只能标为 `partial`。
- 仅记录可验证的模型、token、工具和成本数据；未知 token 或成本填 `0` 并说明原因，不得编造。
- L3/L4 先交付状态卡，随后补证据；账本记录 `startup_ms`、`routing_ms`、`context_load_ms`、`tool_ms`、`model_ms` 和 `first_useful_output_ms`。
- L0-L4 的上下文、预算、沙箱和状态转换以 `agent-runtime-policy.yaml` 为准；预算耗尽时冻结当前结果，说明待验证项，不得无限继续查找或调用工具。
- 删除、覆盖、格式化、递归移动前必须运行 `.qianlima/scripts/check-command-safety.ps1`。其结果为 `deny` 时不得执行；为 `confirmation_required` 时先列出绝对路径和影响范围，等待明确二次确认。
- L2+ 涉及 ASIN、SKU、广告活动或关键词时，可读取匹配的本地 Memory Card；卡片过期、冲突或 L4 决策时必须回读原始数据，不能把记忆当作事实。
