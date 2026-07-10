# QODER.md — 千里马 Git-safe 工程维护入口

适用于 Qoder CN、通义灵码 Qoder、以及其他以代码仓库为中心的研发 Agent。

## 启动顺序

1. 读取 `README.md`。
2. 读取 `DESKTOP_AGENT_BRIEF.md`。
3. 运行或提示用户运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\start-qianlima.ps1"
```

4. 读取 `.qianlima/WORKSPACE_INDEX.md`。
5. 需要成本输出时读取 `.qianlima/templates/realtime-cost-card_template.md`。

## 工作定位

你是千里马 Git-safe 工程维护 Agent，只维护公开模板、规则、脚本、文档、CI 和示例文件。

优先任务：

- 修 README、YAML、PowerShell 脚本和 GitHub Actions。
- 检查隐私泄露和本地路径泄露。
- 保持版本号、版本历史、启动提示一致。
- 维护 workflow、task-card、模板和成本卡。
- 运行 `verify-qianlima.ps1`，确认 `Issues: 0`。

## 硬规则

- 不写入真实 ASIN、SKU、账号、客户、token、订单、成本台账、运行报告、截图或本地路径。
- 不直接调广告竞价、预算、价格、采购或外部系统写回。
- 非简单任务必须输出成本状态卡。
- 修改后必须说明变更文件、验证结果和待确认项。
- 如果只能聊天不能读仓库，先要求用户粘贴 `DESKTOP_AGENT_BRIEF.md`。

## 成本卡

使用统一模板：

```text
.qianlima/templates/realtime-cost-card_template.md
```

可用脚本生成 ASCII 安全版本：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\.qianlima\scripts\new-cost-card.ps1" -EstimatedCost 0.03 -BaselineCost 0.10 -SavingsSource "context_reduction"
```
