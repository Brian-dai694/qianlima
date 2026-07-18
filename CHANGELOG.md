# 变更历史 · Changelog

本项目遵循语义化版本。日期为公开模板仓的发布日。

## [v2.7.5] - 2026-07-18
- 个人版与企业版统一共享同一套亚马逊运营能力目录，覆盖报告、计划、利润、合规、选品、Listing、供应链、库存、广告、售后与根因复盘。
- 新增日/周/月/季/年度报告与利润口径规格，明确时间窗口、数据来源、假设和验证要求。
- 新增共享 MCP 能力与端口规划：业务域独立端口、默认不监听、仅回环绑定、任务结束撤销，不授予业务写入权限。
- 增加 MCP 端口规划回归测试，验证端口唯一性、能力覆盖、Grant 检查和零外部调用。

## [v2.7.4] - 2026-07-17
- Agent Runtime adapters: Codex supervisor, CodeWhale, Claude Code, Raven, plus discover-only Mimo, Kimi, Gemini, Aider, OpenCode, and Goose entries.
- Added grant, revocation, expiry, risk ceiling, Plan/Execute, sandbox, timeout, path, and secret guards with adapter regression coverage.
- Added local CLI discovery and safe startup contracts; unknown vendor CLIs remain discover-only until their command and sandbox contracts are verified.

## [v2.7.3] - 2026-07-15
- Codex 体感提速：普通对话、L0/L1 快答和同主题续问不再触发启动脚本或重复读取上下文。
- 新增单调用上下文装配器、显式会话租约、缓存版本校验、路由歧义失效和 L4 强制启动门禁。
- 增加上下文装配回归测试，覆盖首次路由、租约复用、歧义路由和高风险任务。
- macOS/Linux 增加显式 PowerShell 安装器，默认只预览，不静默安装系统依赖。

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
