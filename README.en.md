# Qianlima — An AI Agent Harness for Amazon Operations

**English** · [中文](README.md)

[![CI](https://github.com/Brian-dai694/qianlima/actions/workflows/qianlima-verify.yml/badge.svg)](https://github.com/Brian-dai694/qianlima/actions/workflows/qianlima-verify.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-v2.7.3-blue.svg)](CHANGELOG.md)
[![PowerShell](https://img.shields.io/badge/PowerShell-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)

> Version v2.7.3 | 2026-07-15 · See [CHANGELOG.md](CHANGELOG.md)

Qianlima is an **AI Agent Harness** for Amazon sellers. It is not another "keyword tool" or "ad management dashboard" — it is an **agent governance layer** that lets an LLM execute Amazon operations tasks reliably, safely, and traceably.

## Core idea

> A harness is not a prompt template — it is a runtime system.
> It observes itself, diagnoses problems, accumulates experience, and keeps improving.

This project draws on [Lilian Weng — Harness Engineering for Self-Improvement (2026)](https://lilianweng.github.io/posts/2026-07-04-harness/) and several SOTA projects. v2.7.1 completes public, safe templates for layered startup, runtime policy, command safety, evaluation, observability, memory cards, sub-agent orchestration, and stateful loops.

## Architecture

```text
Qianlima Harness v2.7.3
├── Scenario router        → load per scenario, minimize unnecessary context
├── Health self-check      → validate skeleton, index, and references at startup
├── Loop Engineering       → SDR / EVR / PBV / EDA execution loops
├── Evolutionary refine    → fix / tune / A/B / extract / evolve feedback loop
├── Sub-agent orchestration→ task splitting, resource limits, handoff protocol
├── Context 2.0            → dynamic context allocation, smart compression, live monitoring
├── Compression defense    → prevents summaries from dropping constraints or bypassing safety
├── Policy Adapter         → decouples policy generation, env observation, action scoring
├── Skill registry         → standardized trigger / scope / capability / quality gate
├── Natural-language router→ maps a user request to a skill / workflow / MCP
├── Realtime cost card     → shows cost, savings, continue-or-stop per non-trivial task
├── Layered startup        → L0-L4 risk-based loading, fast state check on cache hit
├── Runtime policy         → budget, sandbox, state machine, L4 second confirmation
├── Command-safety hook    → pre-blocks delete / overwrite / format / out-of-bounds paths
├── QianlimaEval           → layered acceptance on source, risk, ledger, first-token latency
├── Memory Cards           → local operational memory with source, TTL, and confidence
├── Maker / Checker        → sub-agent context isolation; parent keeps external decision rights
├── Stateful EVR loop      → traceable execute / verify / refine cycle
├── Multi-agent entrypoints→ Codex / Claude / Manus / Qoder CN / Lingma / LinkAI / Obsidian / Desktop
├── Local knowledge base   → Obsidian Vault, MOC, note templates, public/private separation
├── KV-cache optimization  → stable prefixes and cache-hit strategy
└── Config evolution trace → forward / rollback / diff / audit migration records
```

## Quick start

### 1. Clone

```bash
git clone https://github.com/Brian-dai694/qianlima.git
cd qianlima
```

### 2. Configure private data

The public repo keeps only sanitized templates. Put real data only in your private fork or local working copy.

```bash
cp .qianlima/data-sources.example.yaml .qianlima/data-sources.yaml
cp .qianlima/work.example.ws .qianlima/work.ws
# Then edit locally with real values:
# data-sources.yaml: tokens, ERP URLs, etc.
# work.ws: ASINs, cost, margin, keywords, etc.
```

### 3. Initialize the workspace

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\start-qianlima.ps1"
```

The startup script generates `.qianlima/WORKSPACE_INDEX.md` and `.qianlima/workspace-index.json`. An agent entering the repo should read `WORKSPACE_INDEX.md` first, then load the minimal startup pack by index.

Per-agent entrypoints: `AGENTS.md` (Codex), `CLAUDE.md` (Claude Code), `MANUS.md` (Manus), `QODER.md` / `LINGMA.md`, `LINKAI.md`, `OBSIDIAN.md`, `DESKTOP_AGENT_BRIEF.md`.

### 4. Trigger a task

In any agent framework that honors this repo's rules, trigger in natural language:

- "run keyword ranks" → `keyword_rank_scan`
- "generate the daily ad report" → `daily_ad_report`
- "compare competitors" → `competitor_comparison`
- "calculate profit" → `profit_check`

## Privacy boundary

This repo is a **Git-safe public template**. Never commit real operational data: API keys, tokens, credentials, customer PII, account IDs, backend exports, private cost ledgers, decision logs, screenshots, reports, or local machine paths. The default `.gitignore` excludes generated indexes, run logs, ledgers, decision logs, reports, and local secrets.

Before publishing or opening a PR, run the public-safe check:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\.qianlima\scripts\verify-qianlima.ps1"
```

## CI

`.github/workflows/qianlima-verify.yml` runs on push and PR: startup skeleton validation, strict public-safe verification, runtime safety-gate checks, and a negative test asserting that an unconfirmed high-risk action is blocked.

## Dependencies

- **Agent framework**: CodeWhale, Claude Code, or any agent system that reads YAML governance files
- **MCP tools**: Sorftime MCP, Pangolinfo MCP
- **Browser automation**: Kimi WebBridge (optional, for Lingxing ERP extraction)
- **Feishu**: lark-cli (optional, for sheet sync)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Please read the privacy rules and run `verify-qianlima.ps1` before submitting.

## References

- Lilian Weng. "Harness Engineering for Self-Improvement." 2026.
- XPolicyLab. Policy adapter and server-client separation pattern.
- zsLiu2003/Comattack. COMA compression attack threat model.

## License

[MIT](LICENSE)
