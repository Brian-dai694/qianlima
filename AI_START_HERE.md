# AI 启动入口

任何大模型、Agent、助手或自动化工具打开“千里马计划”工作区时，先执行启动索引。

## 第一步：生成工作区索引

运行根目录脚本：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\start-qianlima.ps1"
```

普通用户也可以使用中文入口：`启动千里马计划.ps1`。

这个脚本会自动生成：

```text
.qianlima/WORKSPACE_INDEX.md
.qianlima/workspace-index.json
.qianlima/logs/bootstrap-qianlima-latest.json
```

## 第二步：先读索引

索引生成后，必须先读：

```text
.qianlima/WORKSPACE_INDEX.md
```

然后再按索引里的顺序读取：

```text
.qianlima/README.md
.qianlima/work.ws
.qianlima/workflow-index.yaml
.qianlima/risk-rules.yaml
.qianlima/context-policy.yaml
.qianlima/communication-protocol.yaml
.qianlima/runtime-protocol.yaml
.qianlima/user-profile.yaml
.qianlima/model-adapters.yaml
```

日常任务优先使用最小启动包：

```text
.qianlima/WORKSPACE_INDEX.md
.qianlima/work.ws
.qianlima/risk-rules.yaml
.qianlima/context-policy.yaml
```

只有新任务类型、工作流变化、模型交接或架构调整时，才读取完整启动包。

## 第三步：按任务加载文件

不要一次性读取整个工作区。

根据用户说的话选择对应任务卡：

```text
.qianlima/task-cards/
```

再读取对应 workflow、template、data-sources 和 file-registry。

如果任务涉及多个文件、多个项目、模型交接、场景联动或事件传递，必须读取：

```text
.qianlima/communication-protocol.yaml
```

所有任务都必须按运行协议执行：

```text
.qianlima/runtime-protocol.yaml
```

如果目标是先了解普通用户、识别工作场景或从资料里抽取画像，先读取：

```text
docs/User Profile and Work Scenario Discovery 用户画像与工作场景发现.md
```

完整的文档分组和阅读顺序见 `docs/README.md`。

## 第四步：记录 Token 与费用

每次任务结束后，必须把模型使用情况记录到：

```text
.qianlima/usage-ledger/
```

记录格式参考：

```text
.qianlima/templates/token-usage-record_template.yaml
```

当前最小启动包估算为 **6,622 到 12,140 input tokens**；标准启动包估算为 **11,174 到 20,485 input tokens**。实际任务还要加上任务卡、workflow、模板、数据源、工具返回和最终输出。

## 强制规则

- 启动时必须先生成索引。
- 没有索引，不开始任务。
- 索引过旧，先重新生成。
- 长文件和多文件任务必须按 `.qianlima/context-policy.yaml` 压缩。
- 跨文件、跨项目、跨场景和模型交接必须按 `.qianlima/communication-protocol.yaml` 传引用、摘要和事件。
- 所有任务必须按 `.qianlima/runtime-protocol.yaml` 走 SessionStart、BeforeToolUse、AfterToolUse、FinalCheck。
- 高风险动作必须按 `.qianlima/risk-rules.yaml` 处理。
- 调竞价、改预算、写飞书表、发送外部消息等运营动作必须写决策日志，并验证是否真的生效。
- 每次任务必须记录 input tokens、output tokens、模型名、估算费用和记录文件位置。
- 每次任务结束后进入 Loop Engineering：评估结果、分析问题、改进规则或模板，并记录到日志/反馈/使用台账。
- 根目录只保留入口和总览，正文文档放到 `docs/`。
- 每次优化必须同时看 token 成本和工作结果，不能只追求更少上下文。
