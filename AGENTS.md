# 千里马计划 Agent 启动规则

任何 Agent、代码助手、大模型工作流或自动化工具在本目录工作时，必须先完成启动索引。

## 必做步骤

1. 先运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\start-qianlima.ps1"
```

2. 查看启动结果：

- 如果显示 `Startup mode: cached`，说明规则和目录未变。低风险、高频任务只读取 `.qianlima/CODEX_BOOT.md` 和 `.qianlima/codex-router.json`，按命中的任务卡继续；普通聊天直接回答，不加载运营配置。
- 如果显示 `mode: refreshed`，或任务模糊、跨领域、高风险、配置刚修改，则读取完整工作区索引。

3. 完整启动索引：

```text
.qianlima/WORKSPACE_INDEX.md
.qianlima/CODEX_BOOT.md
.qianlima/risk-rules.yaml
```

## 工作规则

- 不要一次性读取整个工作区。
- 配置或目录变更后使用 `start-qianlima.ps1 -Force` 重建索引和校验；缓存损坏会自动回退到完整启动。
- `codex-router.json` 只用于低风险快速路由。高风险、歧义或跨系统任务必须回读 `natural-language-router.yaml`、`risk-rules.yaml` 和对应任务卡。
- 先根据用户任务选择 `.qianlima/task-cards/` 中的任务卡，再读取对应 workflow 和 template。
- 只有长文件、多文件任务才读取 `context-policy.yaml`；只有需要模型选择时才读取 `model-adapters.yaml`。
- 只有需要业务状态或真实数据时才读取私有 `work.ws`、`data-sources.yaml` 和 `file-registry.yaml`。
- 需要数据时再读取 `.qianlima/data-sources.yaml` 和 `.qianlima/file-registry.yaml`。
- 长文件、多文件任务必须按 `.qianlima/context-policy.yaml` 处理。
- 高风险动作必须按 `.qianlima/risk-rules.yaml` 处理。
- 输出结果要说明数据来源、待验证项和使用情况。

如果启动索引失败，先修复索引或缺失文件，不要直接开始业务任务。
