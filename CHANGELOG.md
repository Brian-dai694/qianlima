# 变更历史 · Changelog

本项目遵循语义化版本。日期为公开模板仓的发布日。

## [v2.7.2] - 2026-07-14
- 跨平台启动：新增 `start-qianlima.sh`（macOS/Linux 入口，检测 `pwsh`、缺失即明确报错，不谎报成功；透传 `-SkipValidation`/`-Force`/`-Quiet`）
- 文档补 macOS/Linux 命令（README/AGENTS/CLAUDE/AI_START_HERE）
- CI 新增 `verify-macos` job：`pwsh -File` + `.sh` wrapper + 严格公开校验
- `.gitattributes` 固定 `*.sh`/`*.command` 为 LF，防 CRLF 破坏 shebang
- 说明：`start-qianlima.ps1` 已用 `Invoke-QianlimaScript`（`& $Path` 同进程调用），本身即 pwsh 兼容，无需改动

## [v2.7.1] - 2026-07-13
- 公开 harness 版本号对齐 v2.7.1；补齐分层启动、运行时策略、命令安全、评估、观测、记忆卡、子代理分工与状态化 Loop 的安全模板
- 新增安全 agent harness 运行时（runtime-protocol / task-runtime）

## [v2.7.0] - 2026-07-12
- 轻量任务运行时（task runtime）：可执行运行时骨架、任务执行器、跨文件协作协议

## [v2.6.9] - 2026-07-11
- 分级响应体验（staged response）

## [v2.6.8] - 2026-07-11
- 成本控制与快速启动；浏览器任务空间治理（browser task space）

## [v2.6.7] - 2026-07-10
- QianlimaEval 评估层（来源命中率、人本审阅、首字延迟的分层评估）

## [v2.6.6] - 2026-07-09
- Obsidian vault 导出

## [v2.6.5 ~ v2.6.1] - 2026-07
- v2.6.5 LinkAI 入口 · v2.6.4 Lingma / Qoder 入口 · v2.6.3 标准成本卡
- v2.6.2 实时成本节省 · v2.6.1 压缩攻击防御

## [v2.2 ~ v2.5.1] - 2026-06 ~ 2026-07
- v2.5.x 版本迭代
- v2.4 治理框架快照（隐私已剔除）
- v2.3 Raven 风格 Agent 模板 + 主动性模块
- v2.2 Harness Engineering + 多个 SOTA 方法落地（loop-engineering、KV-cache 优化等）

## [foundation] - 2026-06-30
- 千里马 harness 基础：数据上下文层 + 广告运营日报 Agent

[v2.7.1]: https://github.com/Brian-dai694/qianlima/releases
