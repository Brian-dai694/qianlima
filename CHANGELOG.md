# 变更历史 · Changelog

本项目遵循语义化版本。日期为公开模板仓的发布日。

## [v2.7.9] - 2026-07-21
- 个人版新增四段式学习管线：资源摘要、局部计划、显式 Grant 只读执行、验证收敛。
- 默认无后台任务、无自动 Skill 安装、无网络、无远程/集群执行；OneSkills 仅作为结构参考，不直接安装。
- 新增个人学习计划边界校验和回归测试，拒绝自动启动、网络/端点字段、SSH/集群工具、业务写入和直接委派。

## [v2.7.8] - 2026-07-21
- 个人版仅预留显式启动的本地 stdio 证据核验模式，唯一工具为 `qianlima_readonly_evidence_task`。
- 每次调用必须绑定任务匹配、未过期、未撤销的最小 Grant；强制无网络、无业务写入、不可委派和最高 L3。
- 新增本地只读 Agent 适配器、统一个人审计事件、Evidence Receipt 和 11 项拒绝回归测试。
- 不接受端口、URL、远程端点、Agent Card 配置或远程派发；主 Harness 和企业版内容保持不变。

## [v2.7.7] - 2026-07-20
- 个人版渐进式治理：普通聊天和续问保持快速路径，风险升高时才显示治理状态。
- 偏好支持语言、篇幅、展示顺序、工具偏好和工作流建议，并以追加版本支持编辑、停用、回退和删除。
- 个人记忆按任务相关 Chunk 选择，排除无关、过期、未确认和敏感内容。
- 增加一键清除个人经验入口，清除偏好、Chunk 和候选内容。
- Skill 安装先做静态检查，默认受限、无网络、无自动启动。
- 保持无外部 Agent、无业务写入和主 Harness 核心文件冻结。

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
