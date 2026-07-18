# 规格驱动治理

千里马 Overlay 采用以下生命周期：

`Constitution -> Specify -> Plan -> Tasks -> Analyze -> Implement -> Converge`

- `Constitution`：读取 `north-star-protocol.json`，确定不可违反原则。
- `Specify`：创建 Agent 准入规格，写清目标、数据、风险、预算、验证和停止条件。
- `Plan`：生成 work order、Grant、Runner 与核验计划。
- `Tasks`：任务只使用一次性、过期、可撤销授权。
- `Analyze`：检查规格与北极星、风险、数据和执行合同的一致性。
- `Implement`：只允许通过 Overlay Gateway 的受控 dry-run 或已批准 Runner。
- `Converge`：形成影子收敛、冻结或晋升候选；不自动修改主 Harness。

主 Harness 保持只读，规格文件和检查脚本属于 Overlay 扩展层。

所有 Overlay Gateway 调用必须携带通过 Analyze 的 Pipeline 规格；规格必须与本次 Grant 的任务、Agent 和 Runner 绑定。
