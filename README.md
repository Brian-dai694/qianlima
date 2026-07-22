# 北极星企业版 — 可信 Agent 治理控制平面

[中文](README.md) · [English](README.en.md)

[![CI](https://github.com/Brian-dai694/beijixing/actions/workflows/qianlima-verify.yml/badge.svg)](https://github.com/Brian-dai694/beijixing/actions/workflows/qianlima-verify.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-v2.7.9-blue.svg)](CHANGELOG.md)
[![PowerShell](https://img.shields.io/badge/PowerShell-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)

> 当前版本：v2.7.9 · 企业版配置版本：0.1.0 · 2026-07-22

北极星企业版用于统一治理企业员工使用的 Codex、Claude Code、CodeWhale 及其他 Agent。它不替代这些 Agent，而是在其外层决定：谁能使用、可以看到什么数据、能够调用哪些 MCP、预算多少、结果是否可信，以及何时必须审批、撤销或冻结。

## 北极星协议

> 任何接入的 Agent，都必须经过准入、最小授权、证据核验、预算约束、审计与可撤销控制。

硬边界：

- Agent Card 只是能力声明，不是权限。
- API 所有权不代表企业数据访问权。
- 安装 Agent 不代表获得 MCP 或业务写入权。
- 员工 Agent 只能使用任务级、短时、可撤销的 Grant。
- 上传、发送、删除和业务系统写入按企业 L4 治理。
- 生产规则改进只能生成候选，必须经过回放、仿真、独立核验和人工晋升。

## 企业架构

```text
老板 / 业务负责人 / 员工 / IT 安全管理员
                    |
             北极星治理 Broker
     ┌──────────────┼──────────────┐
     |              |              |
  身份与组织      策略与预算      审批与审计
     |              |              |
     └──────────────┼──────────────┘
                    |
          本机 Connector + 沙箱 Runner
                    |
       Codex / Claude Code / CodeWhale / 其他 Agent
                    |
       MCP / Skills / 文件 / ERP / 业务系统
```

北极星是控制平面；Agent 是执行平面；MCP 和 Skills 是工具平面。默认禁止 Agent-to-Agent 直连，所有二次委派都必须回到 Broker 重新授权。

## 四种部署模式

企业只需回答两个问题：是否统一购买 API，是否要求统一 Agent。

| 模式 | API | Agent | 默认治理 |
|---|---|---|---|
| E1 | 企业统一 | 企业统一 | 标准化程度最高 |
| E2 | 企业统一 | 员工从批准名单选择 | 默认推荐 |
| E3 | 员工或部门自带 | 企业统一 | BYOK，仅保存密钥引用 |
| E4 | 员工或部门自带 | 员工自选 | 默认 T1，验收后逐步授权 |

选择模式不会自动授予内部数据、MCP、网络或执行权限。

## 企业 L0-L4

| 等级 | 企业含义 | 典型动作 |
|---|---|---|
| L0 | 无企业数据的普通交流 | 解释、公开知识问答 |
| L1 | 公开或低敏只读分析 | 公开资料研究、草稿 |
| L2 | 部门内部只读任务 | 脱敏数据分析、报告生成 |
| L3 | 跨系统或受控内部协作 | 受控 MCP、跨部门引用 |
| L4 | 产生外部或业务状态变化 | 上传、发送、删除、改价、预算、采购、ERP 写入 |

L4 不等于全部交给老板逐条审批。系统按业务责任人、金额阈值、可逆性和批量授权路由；重大治理变更才要求老板或双人确认。

## 组织与员工

企业版提供四种新手角色：

- 老板：查看结果、重大风险和治理决策，不承担日常逐条审批。
- 业务负责人：管理项目、员工范围、MCP 准入和异常处理。
- 员工：用自然语言发起任务，只看到与当前工作相关的权限和结果。
- IT/安全管理员：管理身份、设备、Runner、密钥引用和安全事件，不读取无关业务内容。

员工生命周期覆盖入职、调岗、停职、离职和紧急隔离。调岗执行“先撤销、后授权”，员工记录和审计事件不可物理删除。

## MCP 与业务能力

企业版预留通用 MCP 平台，不绑定单一厂商，覆盖 ERP、财务、税务、海关、物流、库存、广告、市场研究、协作平台和文件系统等能力。

员工 Agent 经业务负责人批准后，可以通过本机 Connector 使用短时 MCP 会话；Connector 仍会逐次检查员工、设备、Agent 版本、任务、数据范围、预算和 Grant 状态。

当前领星、税务、海关及其他 MCP 均为接口合同与机械门禁，未在公开仓中配置真实端点、凭据或业务写入权限。

## 模型协作

模型融合不是多个模型聊天，而是受治理的证据协作：L0-L2 默认单模型，L3 才允许独立候选与证据核验，L4 只能生成候选并进入人工确认。模型档案和 Fusion Plan 见 `.qianlima/model-portfolio.yaml` 与 `.qianlima/fusion-plan-schema.yaml`。

## 业务成果

企业版覆盖选品上架、采购、物流履约、库存、流量转化、广告、活动、售后、清货与复盘，并支持：

- 日报、周报、月报、季报和年报。
- 月度、季度和年度计划。
- 日、周、月、季、年度利润口径。
- Listing 利润、标题、主图、五点和长描述成果包。
- 业务端、成果端、失败端、核心问题端和处理端五视图。
- 踩坑日志、改进候选、回放、仿真和人工晋升的复利系统。

## 快速开始

### 1. 克隆

```bash
git clone https://github.com/Brian-dai694/beijixing.git
cd beijixing
```

### 2. 选择 E1-E4

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File '.\enterprise 企业版\select-enterprise-deployment-mode.ps1'
```

### 3. 创建组织配置

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File '.\enterprise 企业版\new-enterprise-organization.ps1'
```

私有组织配置只写入 `.qianlima/local-data/enterprise/`，不会进入 Git。

### 4. 检查企业运行环境

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File '.\enterprise 企业版\test-enterprise-environment.ps1' -PassThru
```

企业版默认要求批准的隔离 Runner。缺少 Docker、Linux 容器后端、批准镜像或虚拟化能力时会返回 `blocked`，不会降级为不受控执行。

### 5. 启动企业版

Windows：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File '.\enterprise 企业版\start-enterprise.ps1'
```

macOS/Linux：

```bash
bash 'enterprise 企业版/start-enterprise.sh'
```

完整说明见 [企业版 README](enterprise%20企业版/README.md) 和 [分层使用说明书](enterprise%20企业版/企业版分层使用说明书.md)。

## 当前成熟度

| 范围 | 状态 |
|---|---|
| 企业治理合同 | 已实现并有离线回归 |
| E1-E4 部署模式 | 已实现 |
| 组织、员工和 L0-L4 | 已实现 |
| MCP/领星接口 | 已预留，默认禁用 |
| 真实企业身份与 SSO | 需要部署配置 |
| 真实沙箱 Runner | 需要 Docker/批准镜像与 Attestation |
| ERP、税务、海关写入 | 未在公开仓启用 |

部署就绪不等于执行授权。任何真实业务写入仍需任务级 Grant、审批、预检快照、审计和回滚条件。

## 验证

GitHub Actions 在 Windows 和 macOS 验证共享 Harness，并在 Windows 运行全部企业版离线回归。环境部署检查不会在公共 CI 中尝试安装 Docker 或获取企业凭据。

本地运行企业回归：

```powershell
$tests = Get-ChildItem -LiteralPath '.\enterprise 企业版' -Filter 'test-*.ps1' -File |
  Where-Object { $_.Name -ne 'test-enterprise-environment.ps1' }
foreach ($test in $tests) {
  powershell -NoProfile -ExecutionPolicy Bypass -File $test.FullName -PassThru
  if ($LASTEXITCODE -ne 0) { throw "Failed: $($test.Name)" }
}
```

## 主 Harness

企业版是 Overlay，不复制或修改主 Harness。内部仍复用 `.qianlima/`、`start-qianlima.ps1`、AGENTS/Claude/其他 Agent 入口和既有安全门。主 Harness 的开发说明见 [.qianlima/README.md](.qianlima/README.md)。

## 隐私与安全

公开仓只允许脱敏模板。禁止提交 API Key、Token、客户数据、账号信息、真实成本、业务导出、截图、运行日志、审计账本和本机绝对路径。凭据只能使用 Secret Reference，由操作系统或批准的密钥管理器保存。

## 许可证

MIT
