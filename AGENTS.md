# 千里马计划 Agent 启动规则

任何 Agent、代码助手、大模型工作流或自动化工具在本目录工作时，先判定任务层级；L0 普通聊天可绕过启动索引，其余任务按以下规则处理。

## 必做步骤

1. L0 普通聊天、简单事实和非运营问题：直接答，不运行启动脚本、不加载运营配置。

2. L1 明确低风险业务任务先运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\.qianlima\scripts\qianlima-status-fast.ps1"
```

若状态为 `ready`，只读取 `.qianlima/CODEX_BOOT.md` 与 `.qianlima/codex-router.json`。L2/L3 还须传入本次 task-card、workflow、template 的 `-RelevantPath`（多个路径用分号分隔），以检查这些文件存在且没有晚于缓存。

3. L2/L3 在快速状态为 `needs_startup` 时运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\start-qianlima.ps1"
```

   macOS / Linux（需先装 PowerShell 7）：`./start-qianlima.sh`

4. L4、高风险任务、规则或目录变更时运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\start-qianlima.ps1" -Force
```

   macOS / Linux：`./start-qianlima.sh -Force`

5. 查看启动结果：

- 如果显示 `Startup mode: cached`，说明规则和目录未变。低风险、高频任务只读取 `.qianlima/CODEX_BOOT.md`（若存在）和 `.qianlima/codex-router.json`，按命中的任务卡继续；普通聊天直接回答，不加载运营配置。
- 如果显示 `mode: refreshed`，或任务模糊、跨领域、高风险、配置刚修改，则读取完整最小启动包。

6. 完整启动包：

```text
.qianlima/WORKSPACE_INDEX.md
```

## 工作规则

- 不要一次性读取整个工作区；缓存命中时不要重复读取完整 `work.ws` 和长治理文件。
- 配置或目录变更后使用 `start-qianlima.ps1 -Force` 重建索引和校验；缓存损坏会自动回退到完整启动。
- `codex-router.json` 只用于低风险快速路由。高风险、歧义或跨系统任务必须回读 `natural-language-router.yaml`、`risk-rules.yaml` 和对应任务卡。
- L0 普通聊天直接回答；L1 只读短启动包和快速路由；L2 再读任务卡与 workflow；L3 先发状态卡和初判再取证；L4 回读风险规则与原始数据并要求二次确认。
- 根据用户任务选择 `.qianlima/task-cards/` 中的任务卡。
- 需要数据时再读取 `.qianlima/data-sources.yaml` 和 `.qianlima/file-registry.yaml`。
- 长文件、多文件任务必须按 `.qianlima/context-policy.yaml` 处理。
- 高风险动作必须按 `.qianlima/risk-rules.yaml` 处理。
- 输出结果要说明数据来源、待验证项和使用情况。
- 每个 workflow 完成前必须调用 `.qianlima/scripts/record-qianlima-usage.ps1` 写入 `.qianlima/usage-ledger/runs.jsonl`。未写入账本时，任务只能标为 `partial`，不能标为完成。
- 成本、token 只记录可验证的实际值；未知值填 `0` 并注明原因，不得编造。
- L3/L4 在账本记录启动、路由、上下文、工具、模型与首次有效输出的耗时分解。
- 运行时预算、沙箱边界和状态机遵循 `.qianlima/agent-runtime-policy.yaml`；预算耗尽时输出已获得结论和待验证项，状态为 `frozen` 或 `partial`，不得绕过风险门禁继续执行。
- 删除、覆盖、格式化、递归移动前必须运行 `.qianlima/scripts/check-command-safety.ps1`。`deny` 不得执行；`confirmation_required` 必须先展示绝对路径、影响数量和可恢复性，等待用户明确二次确认。

如果启动索引失败，先修复索引或缺失文件，不要直接开始业务任务。
