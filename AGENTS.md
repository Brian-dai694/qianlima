# 千里马计划 Agent 启动规则

任何 Agent、代码助手、大模型工作流或自动化工具在本目录工作时，必须先完成启动索引。

## 必做步骤

1. 先运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\start-qianlima.ps1"
```

2. 再读取：

```text
.qianlima/WORKSPACE_INDEX.md
```

3. 然后按索引顺序读取最小启动包：

```text
.qianlima/README.md
.qianlima/work.ws
.qianlima/workflow-index.yaml
.qianlima/risk-rules.yaml
.qianlima/context-policy.yaml
.qianlima/model-adapters.yaml
```

## 工作规则

- 不要一次性读取整个工作区。
- 根据用户任务选择 `.qianlima/task-cards/` 中的任务卡。
- 需要数据时再读取 `.qianlima/data-sources.yaml` 和 `.qianlima/file-registry.yaml`。
- 长文件、多文件任务必须按 `.qianlima/context-policy.yaml` 处理。
- 高风险动作必须按 `.qianlima/risk-rules.yaml` 处理。
- 输出结果要说明数据来源、待验证项和使用情况。
- 每次任务结束后，把 input tokens、output tokens、模型名、估算费用写入 `.qianlima/usage-ledger/`；格式参考 `.qianlima/templates/token-usage-record_template.yaml`。

如果启动索引失败，先修复索引或缺失文件，不要直接开始业务任务。
