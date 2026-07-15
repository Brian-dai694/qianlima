# AI 启动入口

本文件不是每轮任务的强制启动命令。先按根目录 `AGENTS.md` 判断：普通聊天和同主题续问直接处理；只有需要本地业务数据、workflow、外部工具或高风险执行时，才进入千里马运行时。

## 业务任务入口

L2/L3 任务使用一次调用装配最小上下文：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\.qianlima\scripts\qianlima-context-fast.ps1" `
  -TaskText "<用户请求>" `
  -ContextLevel L2 `
  -RelevantPath "<task-card;workflow;template>" `
  -AutoStart -AsJson
```

返回 `startup_completed: true` 时不要再次运行启动脚本。L4 仍需读取风险规则、原始数据并等待二次确认。

## 运行原则

- 按需加载，不扫描整个工作区。
- 续问继承当前上下文，不重复启动、读取或记账。
- 高风险操作必须经过命令安全检查和用户确认。
- 公开仓只提交脱敏模板，不提交 `work.ws`、真实数据源、报告、账本、日志或凭据。
