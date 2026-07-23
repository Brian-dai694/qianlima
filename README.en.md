# Qianlima Personal Edition — Local-First Amazon Agent Workbench

[中文](README.md) · [English](README.en.md)

[![CI](https://github.com/Brian-dai694/beijixing/actions/workflows/qianlima-verify.yml/badge.svg)](https://github.com/Brian-dai694/beijixing/actions/workflows/qianlima-verify.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-v2.8.3-blue.svg)](CHANGELOG.md)

> Current release: v2.8.3 · 2026-07-23

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

### Tiered Memory Retrieval

Personal memory uses three local retrieval tiers:

- `hot`: current task state and frequently used items in the fast local layer.
- `warm`: verified preferences and recent work habits in the local working layer.
- `cold`: long-term reproducible experience in low-cost storage, loaded only when relevant.

Runtime filters by Grant, task relevance, state, classification, and expiry before recall, then ranks the small result by task match, tier, recency, and access frequency. It does not scan and inject the full memory store.

Before an external API, paid tool, or remote Agent call, the user sees the provider, purpose, data scope, estimated cost, cost source, and confirmation state. Unknown cost is recorded as `0` and marked unknown; network remains disabled by default.

### Professional Tool Learning Mode

The personal edition may learn the design of a professional MCP tool without installing or running it. The adapter only evaluates sanitized tool manifests offline:

| Profile | Learned design | Personal simulation result |
|---|---|---|
| `reverse-readonly` | Read-only queries, decompilation, call graphs, and data flow | Restricted simulation allowed |
| `reverse-triage` | Minimal function, string, import/export, and cross-reference triage | Restricted simulation allowed |
| `reverse-edit` | Renaming, comments, and type changes | Blocked in learning mode |
| `reverse-debug` | Patching, debugging, memory writes, and `py_eval` | Blocked in learning mode |

Every simulation requires a stdio design, a reference-only target, and a minimal capability list. URLs, ports, absolute paths, network access, installation, runtime startup, and permission grants are rejected. The adapter returns a structured decision only; it does not connect to IDA, open a listener, or execute a tool.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File '.\.qianlima\scripts\test-professional-tool-governance.ps1'
```

### Personal Harness Acceptance

The personal edition covers lightweight `T/C/L` with basic `O/V`: least-privilege tools, filter-before-recall memory, replayable and stoppable task state, minimal traces, and evidence checks. Enterprise tenancy, enterprise approvals, and fleet governance are outside this edition.

Ordinary tasks use local low-cost filtering first. Only L2+, evidence conflicts, missing required fields, or an explicit deep-review request can enter the budgeted review stage, which keeps the original Grant scope. Review is suppressed by default for L0/L1.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File '.\.qianlima\scripts\test-personal-harness-acceptance.ps1'
```

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

Personal routing, memory, Skill gates, local read-only evidence execution, professional-tool learning simulation, Harness acceptance, file organization, and offline regression are implemented. Network access, remote runners, credentials, MCP endpoints, and business writes are not enabled.

Deployment readiness is not execution authority. Every production write still requires a task Grant, approval, preflight snapshot, audit receipt, and rollback condition.

## Harness

The personal runtime uses `.qianlima/`, `start-qianlima.ps1`, and the repository Agent entrypoints. Internal Harness documentation remains in [.qianlima/README.md](.qianlima/README.md).

## Privacy

The public repository accepts sanitized templates only. Never commit API keys, tokens, customer data, account identifiers, real costs, business exports, screenshots, run logs, audit ledgers, or local absolute paths. Credentials must remain Secret References backed by the operating system or an approved secret manager.

## License

MIT
