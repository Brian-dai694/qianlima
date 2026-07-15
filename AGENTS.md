# 千里马计划：Codex 快速入口

本文件是 Codex 在本目录的最小入口。目标是让普通对话和同主题追问不触发千里马运行时。

## 决策顺序

1. **续问短路**：`继续`、`下一步`、`还有吗`、`展开第 N 点`、`再详细一点`、`接着做`，且没有改变目标、数据源、风险或配置时，直接继承当前对话；不运行脚本、不读取启动文件、不写账本。
2. **L0/L1 快答**：普通聊天、解释、头脑风暴、简单只读问题直接回答；不运行 PowerShell，不加载运营配置。
3. **L2/L3 业务任务**：先给一句有用的当前判断，再按需调用一次 `.qianlima/scripts/qianlima-context-fast.ps1`，仅传入相关 task-card/workflow/template 和 `-AutoStart`。不要先单独运行 status 脚本，再运行启动脚本。
4. **L4 或配置变更**：改价、竞价、预算、采购、删除、覆盖、写回、发送外部消息，必须完整启动、回读风险规则和原始数据，并二次确认。

## 不可违反

- 不要扫描整个工作区；不要把摘要当作高风险事实。
- 删除、覆盖、格式化、递归移动前运行 `.qianlima/scripts/check-command-safety.ps1`；`deny` 禁止执行。
- L2+ 的业务 workflow 完成前写 usage ledger；普通聊天和续问不是 workflow，不写账本。
- 成本、token、耗时只记录可验证值；未知填 `0` 并说明原因。
- 高风险操作永远不使用会话租约；租约只保存版本和路由元数据，不保存隐私、原始数据或模型输出。

## 需要进入运行时

读取 `.qianlima/CODEX_BOOT.md`，再按任务选择 task-card/workflow。运行时预算、状态机、沙箱和风险规则以 `.qianlima/agent-runtime-policy.yaml`、`.qianlima/risk-rules.yaml` 为准。

macOS/Linux 使用 `pwsh` 和 `bash start-qianlima.sh`；安装见 `MACOS.md`。
