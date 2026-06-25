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
.qianlima/communication-protocol.yaml
.qianlima/runtime-protocol.yaml
.qianlima/model-adapters.yaml
```

## 工作规则

- 不要一次性读取整个工作区。
- 根据用户任务选择 `.qianlima/task-cards/` 中的任务卡。
- 需要数据时再读取 `.qianlima/data-sources.yaml` 和 `.qianlima/file-registry.yaml`。
- 长文件、多文件任务必须按 `.qianlima/context-policy.yaml` 处理。
- 跨文件、跨项目、跨场景和模型交接必须按 `.qianlima/communication-protocol.yaml` 传引用、摘要、事件和执行状态。
- 所有任务按 `.qianlima/runtime-protocol.yaml` 经过 SessionStart、BeforeToolUse、AfterToolUse、FinalCheck。
- 高风险动作必须按 `.qianlima/risk-rules.yaml` 处理。
- 运营动作必须写 `.qianlima/decision-log.yaml` 格式的决策记录，并完成验证门。
- 输出结果要说明数据来源、待验证项和使用情况。
- 每次任务结束后，把 input tokens、output tokens、模型名、估算费用写入 `.qianlima/usage-ledger/`；格式参考 `.qianlima/templates/token-usage-record_template.yaml`。
- 每次任务都进入 Loop Engineering：执行、评估、分析、改进、记录、再执行；具体见 `Loop Engineering 循环工程.md` 和 `.qianlima/improvement-loop.yaml`。
- 根目录只放入口文件和极少说明；正文内容优先挂到 `docs/README.md`。
- 默认使用最小启动包；只有新任务类型、架构修改或审计时才升级到标准/完整启动。
- 优化目标是同时减少 token 和提升工作结果，不能为了省 token 删除必要来源、风险检查或用户业务上下文。

如果启动索引失败，先修复索引或缺失文件，不要直接开始业务任务。
