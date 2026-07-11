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
.qianlima/codex-router.json
```

首次启动、配置变更或使用 `-Force` 时会重建并校验。未改配置时会显示 `Startup mode: cached`，直接复用已验证的索引和轻量路由，不再重复做完整启动。

## 第二步：先读索引

完整启动后，必须先读：

```text
.qianlima/WORKSPACE_INDEX.md
```

然后只读取核心启动包：

```text
.qianlima/CODEX_BOOT.md
.qianlima/risk-rules.yaml
```

缓存启动且任务低风险时，可先读取：

```text
.qianlima/CODEX_BOOT.md
.qianlima/codex-router.json
```

普通聊天不需要加载运营工作区。高风险、歧义或跨系统任务必须回读完整索引与风险规则。

## 第三步：按任务加载文件

不要一次性读取整个工作区。

根据用户说的话选择对应任务卡，再按需读取对应 workflow、template 与治理文件：

```text
.qianlima/task-cards/
```

- 长文件或多文件：读取 `context-policy.yaml`。
- 需要模型选择或成本预估：读取 `model-adapters.yaml`。
- 需要真实业务状态或数据：读取私有 `work.ws`、`data-sources.yaml` 和 `file-registry.yaml`。

## 可选：EverOS 记忆层

如果用户要求使用跨会话记忆，读取：

```text
.qianlima/everos-memory.yaml
.qianlima/playbooks/everos-memory-playbook.md
```

EverOS 只作为 recall layer。涉及业务结论、高风险动作或数据出处时，仍必须重新读取本地源文件。

## 强制规则

- 启动时必须先生成索引。
- 没有索引，不开始任务。
- 索引过旧，先重新生成。
- 长文件和多文件任务必须按 `.qianlima/context-policy.yaml` 压缩。
- 高风险动作必须按 `.qianlima/risk-rules.yaml` 处理。
