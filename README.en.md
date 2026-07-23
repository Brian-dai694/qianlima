# Qianlima Personal Edition — Local-First Amazon Agent Workbench

[中文](README.md) · [English](README.en.md)

[![CI](https://github.com/Brian-dai694/beijixing/actions/workflows/qianlima-verify.yml/badge.svg)](https://github.com/Brian-dai694/beijixing/actions/workflows/qianlima-verify.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-v2.7.11-blue.svg)](CHANGELOG.md)

> Current release: v2.7.11 · 2026-07-22

Qianlima Personal is a local-first Amazon operations workbench. It keeps business workflows, evidence, and result verification in the project while Codex and other Agents provide interaction and execution.

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

## Personal Boundaries

Personal L0-L4 routing keeps ordinary conversation fast, loads Skills only when a task needs them, and puts external sends, deletes, overwrites, and business writes behind controlled execution. Local stdio MCP interfaces are reserved, while network access, remote execution, business writes, and background loops remain disabled by default.

The repository contains contracts and enforcement gates only. No real endpoint, credential, or production write permission is enabled.

## Model Collaboration

Model fusion is evidence collaboration, not several models chatting. L0-L2 use one model by default; L3 may use independent candidates plus evidence verification; L4 produces candidates only and requires human confirmation. See `.qianlima/model-portfolio.yaml` and `.qianlima/fusion-plan-schema.yaml`.

## Quick Start

```bash
git clone https://github.com/Brian-dai694/beijixing.git
cd beijixing
```

Start on Windows:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File '.\start-qianlima.ps1'
```

Start on macOS/Linux:

```bash
bash './start-qianlima.sh'
```

## Readiness

Personal routing, memory, Skill gates, local read-only evidence execution, file organization, and offline regression are implemented. Network access, remote runners, credentials, MCP endpoints, and business writes are not enabled.

Deployment readiness is not execution authority. Every production write still requires a task Grant, approval, preflight snapshot, audit receipt, and rollback condition.

## Harness

The personal runtime uses `.qianlima/`, `start-qianlima.ps1`, and the repository Agent entrypoints. Internal Harness documentation remains in [.qianlima/README.md](.qianlima/README.md).

## Privacy

The public repository accepts sanitized templates only. Never commit API keys, tokens, customer data, account identifiers, real costs, business exports, screenshots, run logs, audit ledgers, or local absolute paths. Credentials must remain Secret References backed by the operating system or an approved secret manager.

## License

MIT
