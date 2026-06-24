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
.qianlima/model-adapters.yaml
```

## 第三步：按任务加载文件

不要一次性读取整个工作区。

根据用户说的话选择对应任务卡：

```text
.qianlima/task-cards/
```

再读取对应 workflow、template、data-sources 和 file-registry。

## 第四步：记录 Token 与费用

每次任务结束后，必须把模型使用情况记录到：

```text
.qianlima/usage-ledger/
```

记录格式参考：

```text
.qianlima/templates/token-usage-record_template.yaml
```

当前最小启动包估算为 **10,655 到 19,534 input tokens**。实际任务还要加上任务卡、workflow、模板、数据源、工具返回和最终输出。

## 强制规则

- 启动时必须先生成索引。
- 没有索引，不开始任务。
- 索引过旧，先重新生成。
- 长文件和多文件任务必须按 `.qianlima/context-policy.yaml` 压缩。
- 高风险动作必须按 `.qianlima/risk-rules.yaml` 处理。
- 每次任务必须记录 input tokens、output tokens、模型名、估算费用和记录文件位置。
