# Beijixing Enterprise — Trusted Agent Governance Control Plane

[中文](README.md) · [English](README.en.md)

[![CI](https://github.com/Brian-dai694/beijixing/actions/workflows/qianlima-verify.yml/badge.svg)](https://github.com/Brian-dai694/beijixing/actions/workflows/qianlima-verify.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-v2.7.8-blue.svg)](CHANGELOG.md)

> Current release: v2.7.8 · Enterprise profile: 0.1.0 · 2026-07-22

Beijixing Enterprise governs how employees use Codex, Claude Code, CodeWhale, and other Agents. It does not replace those runtimes. It decides who may act, what data they may see, which MCP tools they may call, how much they may spend, whether results are trustworthy, and when work must be approved, revoked, or frozen.

## North Star Protocol

> Every connected Agent must pass admission, least-privilege authorization, evidence verification, budget control, audit, and revocable enforcement.

- An Agent Card is a capability claim, not authority.
- API ownership does not grant access to enterprise data.
- Installing an Agent does not grant MCP or business-write permissions.
- Employee Agents receive task-scoped, short-lived, revocable Grants.
- Upload, send, delete, and business-system writes remain Enterprise L4.
- Improvements create candidates only; production promotion requires replay, simulation, independent verification, and human approval.

## Architecture

```text
Owner / Business Manager / Employee / IT & Security
                         |
               Beijixing Governance Broker
          identity | policy | budget | approval | audit
                         |
             Local Connector + Sandbox Runner
                         |
        Codex / Claude Code / CodeWhale / other Agents
                         |
          MCP / Skills / files / ERP / business systems
```

Beijixing is the control plane, Agents are the execution plane, and MCP/Skills are the tool plane. Direct Agent-to-Agent delegation is denied by default.

## Deployment Modes

| Mode | API | Agent | Default posture |
|---|---|---|---|
| E1 | Enterprise-managed | Enterprise-standard | Maximum standardization |
| E2 | Enterprise-managed | Employee chooses from allowlist | Recommended default |
| E3 | Employee/department BYOK | Enterprise-standard | Secret references only |
| E4 | Employee/department BYOK | Employee-selected | Starts at T1 |

Selecting a mode grants no internal data, MCP, network, or execution authority.

## Enterprise L0-L4

| Level | Meaning |
|---|---|
| L0 | Conversation without enterprise data |
| L1 | Public or low-sensitivity read-only work |
| L2 | Department-internal read-only analysis |
| L3 | Controlled cross-system or cross-department work |
| L4 | External or business-state changes |

L4 approval is routed by responsible owner, threshold, reversibility, and batch scope. The company owner does not approve every routine action.

## Organization and MCP

Four beginner-facing roles are provided: company owner, business manager, employee, and IT/security administrator. Joiner, mover, leaver, suspension, and emergency isolation workflows revoke old access before issuing new access.

The vendor-neutral MCP platform reserves interfaces for ERP, finance, tax, customs, logistics, inventory, advertising, market research, collaboration, and files. Employee Agents may use an approved short-lived MCP session through the local Connector, which checks identity, device, Agent version, task, data scope, budget, and Grant state on every call.

Lingxing, tax, customs, and other MCP integrations in this public repository are contracts and enforcement gates only. No real endpoint, credential, or production write permission is enabled.

## Model Collaboration

Model fusion is evidence collaboration, not several models chatting. L0-L2 use one model by default; L3 may use independent candidates plus evidence verification; L4 produces candidates only and requires human confirmation. See `.qianlima/model-portfolio.yaml` and `.qianlima/fusion-plan-schema.yaml`.

## Quick Start

```bash
git clone https://github.com/Brian-dai694/beijixing.git
cd beijixing
```

Select E1-E4:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File '.\enterprise 企业版\select-enterprise-deployment-mode.ps1'
```

Create the private organization profile:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File '.\enterprise 企业版\new-enterprise-organization.ps1'
```

Check the managed environment:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File '.\enterprise 企业版\test-enterprise-environment.ps1' -PassThru
```

Start on Windows:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File '.\enterprise 企业版\start-enterprise.ps1'
```

Start on macOS/Linux:

```bash
bash 'enterprise 企业版/start-enterprise.sh'
```

See the [Enterprise README](enterprise%20企业版/README.md) for detailed configuration.

## Readiness

Governance contracts, E1-E4, organization roles, employee lifecycle, L0-L4, file organization, and offline regression are implemented. Real SSO, managed Runners, credentials, MCP endpoints, ERP writes, tax, and customs submission still require enterprise deployment and explicit authorization.

Deployment readiness is not execution authority. Every production write still requires a task Grant, approval, preflight snapshot, audit receipt, and rollback condition.

## Shared Harness

Enterprise is an overlay. It reuses the Qianlima core under `.qianlima/` without copying or loosening it. Internal Harness documentation remains in [.qianlima/README.md](.qianlima/README.md).

## Privacy

The public repository accepts sanitized templates only. Never commit API keys, tokens, customer data, account identifiers, real costs, business exports, screenshots, run logs, audit ledgers, or local absolute paths. Credentials must remain Secret References backed by the operating system or an approved secret manager.

## License

MIT
