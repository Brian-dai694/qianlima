# 变更历史 · Changelog

本项目遵循语义化版本。日期为公开模板仓的发布日。

## [v2.8.5] - 2026-07-23
- 新增个人版亚马逊广告异常诊断闭环：本地 CSV 只读计算、异常识别、行动卡、证据回执和可选结果回读。
- 行动卡固定包含问题、证据、建议、影响、权限、预算/出价回滚基线，以及执行后 3 天和 7 天验证指标。
- 个人版不自动改价、改竞价、改预算、暂停广告、联网、外发或写回业务系统；高影响候选只标记为待控制平面确认。
- 新增离线广告闭环回归测试：`12/12 PASS`。

## [v2.8.4] - 2026-07-23
- 新增个人项目价值合同与离线评估器，核心目标从“替代人员”改为提升单位人才创造的可复核业务价值。
- 项目候选必须考虑频率、规则稳定性、历史样本、可度量、可回退、风险隔离和人工核验；行业通用数字、模型自评和命令成功不能作为业务价值证据。
- 新增质量、效率、成本、风险和组织复用五组指标；合格候选只能进入只读、小范围、可回退试点。
- 新增个人项目价值回归测试：`8/8 PASS`，并纳入 `verify-qianlima.ps1`。

## [v2.8.3] - 2026-07-23
- 将 ETCLOVG 提炼为个人版 `T/C/L + 基础 O/V` Harness 验收矩阵，不引入企业租户、企业审批或车队治理。
- 固化“本地低成本筛选 -> L2+ 或证据冲突时受控复核”的两段式路径；复核保持原 Grant、预算和证据约束，L0/L1 默认短路。
- 新增个人版 Harness 验收合同与 `9/9 PASS` 离线测试，并纳入 `verify-qianlima.ps1`。

## [v2.8.2] - 2026-07-23
- 新增个人版专业工具治理学习合同和离线模拟器，借鉴 `ida-pro-mcp` 的 Profile 分层，但不安装、不运行、不联网。
- `reverse-readonly` 与 `reverse-triage` 仅可标记为受限模拟；`reverse-edit`、`reverse-debug`、`py_eval` 和高风险能力在学习模式中阻断。
- 强制 stdio 设计、引用式目标和最小能力清单；拒绝 URL、端口、绝对路径、网络、安装、运行时启动和权限授予。
- 新增专业工具治理回归测试：`8/8 PASS`。

## [v2.8.1] - 2026-07-23
- 个人记忆增加 hot/warm/cold 分层，先过滤 Grant、相关性、状态、分类和时效，再按最近使用与访问频次排序。
- 个人偏好增加关键词、报告格式和分析习惯三类可学习项；它们只影响推荐与表达，不改变权限。
- Execution Plan 增加可回放任务状态机、终态和中止边界。
- 外部 API/付费工具调用预览要求用途、数据范围、成本来源和确认状态；未知成本按 `0` 记录并标记未知。

## [v2.8.0] - 2026-07-22
- 个人版新增 Governed Loop：Builder 只处理任务范围，Checker 只读验证，编排器原样保留检查输出。
- 默认最多 5 轮；全绿立即完成，同错两次、回归、无进展两次、超时或越权自动冻结，用户取消进入 stopped。
- Loop 重试不会扩大 Grant、数据范围、预算、网络权限或业务写入权限。
- 新增个人 Loop 合同、状态驱动器和 8 项回归测试；主 Harness 核心保持冻结。

## [v2.7.11] - 2026-07-22
- 千里马新增 Project Scope，明确绑定店铺、站点、品牌和产品线。
- 新增 Service/Repository 只读数据请求合同，限制来源、选定字段和时间范围，报告层不直接依赖供应商原始响应。
- 新增 startup/background/pre_l4 三档本地健康检查，以及失败位置、来源、累计次数、恢复动作和安全终态的 Failure Receipt。
- 普通问答不加载健康检查；失败只降级、冻结或停止，不自动扩展工具、数据、预算、网络或业务写入权限。

## [v2.7.10] - 2026-07-22
- 千里马新增当前状态/期望状态差异计算，输出可审查的诊断候选，不直接执行业务写入。
- 新增业务 Evidence Pack，统一绑定来源、时间范围、公式、Workflow 版本、假设、不确定性、待验证项和可复跑命令。
- 增加哈希可复算回归测试；状态差异与证据包只写本地运行轨迹，不联网、不改原始数据、不外发。

## [v2.7.9] - 2026-07-21
- 个人版新增四段式学习管线：资源摘要、局部计划、显式 Grant 只读执行、验证收敛。
- 默认无后台任务、无自动 Skill 安装、无网络、无远程/集群执行；OneSkills 仅作为结构参考，不直接安装。
- 新增个人学习计划边界校验和回归测试，拒绝自动启动、网络/端点字段、SSH/集群工具、业务写入和直接委派。
- 千里马新增结构化 Execution Plan、步骤执行回执和 Execute-Verify-Revise 状态机。
- 新增本地只读 CSV Runner；XLSX/Python 仅预检，不自动安装依赖，不联网、不写回、不删除、不委派。
- 执行结果必须带来源引用、行数、警告、待验证项和 Artifact Hash，未验证结果不能标记完成。
- 严格校验脚本纳入执行计划合同、EVR 合同、只读 Runner 合同及其回归测试，并避免因 `.gitattributes` 读取失败中断公开安全扫描。

## [v2.7.8] - 2026-07-21
- 个人版仅预留显式启动的本地 stdio 证据核验模式，唯一工具为 `qianlima_readonly_evidence_task`。
- 每次调用必须绑定任务匹配、未过期、未撤销的最小 Grant；强制无网络、无业务写入、不可委派和最高 L3。
- 新增本地只读 Agent 适配器、统一个人审计事件、Evidence Receipt 和拒绝回归测试。
- 不接受端口、URL、远程端点、Agent Card 配置或远程派发；主 Harness 核心保持冻结。
- Low-risk Skill candidates now auto-release after independent validation; approval prompts are removed from the normal personal workflow.
- High-risk, permission-changing, or attack-surface-changing candidates freeze and keep the prior version active. Automatic rollback remains available.

## [v2.7.7] - 2026-07-20
- 个人版渐进式治理：普通聊天和续问保持快速路径，风险升高时才显示治理状态。
- 偏好支持语言、篇幅、展示顺序、工具偏好和工作流建议，并以追加版本支持编辑、停用、回退和删除。
- 个人记忆按任务相关 Chunk 选择，排除无关、过期、未确认和敏感内容。
- 增加一键清除个人经验入口；Skill 安装先做静态检查，默认受限、无网络、无自动启动。
- 保持无外部 Agent、无业务写入和主 Harness 核心文件冻结。
- Added the Skill self-evolution manager and contract: sanitized feedback, evidence-bound rule abstraction, candidate-only patching, independent replay validation, explicit release records, and rollback events.
- Added regression coverage proving out-of-order changes are denied, production files are never auto-modified, and the append-only evolution trace survives rollback.

## [v2.7.6] - 2026-07-18
- Memory Broker 成为记忆读取的统一入口，支持任务、Grant、状态视图、作用域和撤销校验。
- Complexity Gate 接入 Agent admission 分析，新增 Agent、Pipeline stage 和复杂度提案必须先通过准入。
- 新增 Agent pipeline、Trace、改进候选、记忆状态和企业治理规格合同及回归测试。
- 企业版 overlay 补齐 Runner、组织、连接、MCP、审批、业务交付和文件治理合同；主 Harness 保持冻结。

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
