# 千里马企业级 Agent 治理控制矩阵

## 目标

千里马是治理控制平面，不是裸露的通用 Agent。任何 Agent、CLI、Skill、MCP 或 Runner 接入，都必须经过准入、最小授权、证据核验、预算、审计和可撤销控制。

## 控制矩阵

| 控制域 | 控制要求 | 强制位置 | 证据 | 当前状态 |
|---|---|---|---|---|
| 身份与准入 | Agent Card 只是能力声明，版本或能力变化自动降级 | Agent registry / Broker | Card、版本、合同测试 | 已实现 |
| 权限 | 每次任务签发 Grant，绑定 task、Agent、数据、工具、预算和过期时间 | Grant validator / dispatcher | Delegation Grant、撤销事件 | 已实现 |
| 数据 | 默认只传引用、哈希和脱敏摘要；密钥只能用 Secret Reference | Work order / adapter / Runner | input refs、classification、审计事件 | 部分实现 |
| 执行环境 | 主机直跑拒绝；真实执行必须有注册 Runner 和任务绑定 Attestation | Runner dispatcher | Attestation、Runner receipt | mock 已实现 |
| 网络与外发 | Agent 网络、网页、ERP、文件外发默认拒绝 | Runtime policy / Runner | sandbox decision | 已实现为默认拒绝 |
| MCP | 只允许任务白名单内的只读 MCP，任务结束撤销 | MCP gateway | MCP grant、revoke event | 部分实现 |
| 风险 | L4 必须原始数据回读、预检快照、二次确认、回滚和事后核验 | Risk rules / workflow | confirmation、snapshot、operation trace | 已实现规则层 |
| 证据 | 结论必须带来源、时间范围、假设、不确定性、方法、哈希和独立核验者 | Evidence receipt / verifier | Evidence Receipt | 已实现 |
| 审计 | 授权、拒绝、执行、撤销、验证和最终决定追加写入，不覆盖历史 | Audit writer / run trace | append-only JSONL | 已实现 |
| 失败 | 超时、越权、证据缺失和审计缺口默认收缩权限并冻结 | Failure policy | failure category、freeze、revoke | 已实现规则层 |
| 供应链 | 镜像、CLI、Skill、Agent 版本必须白名单、可回滚、可复验 | Runner registry / evolution policy | digest、contract test、snapshot | 部分实现 |
| 变更 | 生产规则只能候选、回放、人工批准后晋升 | Evolution policy | eval report、promotion log | 已实现 |
| 主 Harness 边界 | AGENTS、BOOT、启动、核心策略和既有安全门只读；新能力走 Overlay | harness-boundary.json / boundary checker | 基线哈希、边界回归 | 已实现 |
| 事故 | 能撤销 Grant、隔离版本、保留回执、通知责任人并创建恢复任务 | Incident response | incident record、new task | 待补运行自动化 |

## 责任边界

`Codex` 负责交互和监督；`CodeWhale/Claude/Raven` 负责受限 Worker 执行；`MCP/Skill` 提供工具和原子能力；`Runner` 提供隔离；`千里马 Broker` 保留准入、授权、验证、审计、回滚和最终采纳权。

## 规格驱动生命周期

Overlay 使用 `Constitution -> Specify -> Plan -> Tasks -> Analyze -> Implement -> Converge`。规格先于委派；Analyze 可以拒绝或冻结；Converge 只生成影子结果或晋升候选，不自动修改主 Harness。

## 声明式 Agent 管线

Agent 管线必须按 `agent-pipeline-contract.json` 顺序运行：输入引用、分类裁剪、授权、执行、Artifact 扫描、独立核验、采纳或冻结。每个 Artifact 元数据必须携带任务、Grant、Agent/版本、Runner、输入哈希、数据分类、预算快照和核验状态。核验或扫描积压时启用背压，停止上游生成；不得自动扩预算或跳过核验。

Overlay Gateway 的 `PipelinePath` 为必需参数，并强制校验 Pipeline 与 Grant 的 `task_id`、`agent_id`、`runner_id` 一致；缺失规格或绑定不一致时，不能进入 Runner dry-run。

## 运行轨迹与失败注入

所有受治理委派使用统一 Trace Envelope，关联 Grant、Artifact、Evidence、Runner、策略版本和预算快照。改进系统只读取脱敏元数据，不读取生产密钥、原始业务内容或执行权限。失败注入覆盖授权过期/撤销、版本漂移、哈希篡改、预算超限、核验冲突和取消后的下游任务；未满足失败动作时必须冻结或拒绝。

## 启用顺序

1. 先通过本地合同和回归测试。
2. 再完成 Docker/WSL/VM Runner 的隔离探针和 Attestation。
3. 再配置专用、可轮换、仅模型 Provider 使用的凭据引用。
4. 先执行只读影子任务，观察证据、延迟、失败和撤销。
5. 最后才考虑 L4 受控写入；必须由人工责任人签署启用决定。

当前 `docker_local_isolated` 保持禁用，不能因为 Docker 安装完成就自动启用。
