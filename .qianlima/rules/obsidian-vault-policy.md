# Obsidian Vault Policy

Version: v2.6.6
Date: 2026-07-09

Qianlima uses Obsidian as a local Markdown knowledge base. Obsidian is for knowledge retention, search, linking, review, and private reflection. It is not an execution layer.

## Vault Separation

Maintain two vault classes:

- `git-safe-vault`: public templates, rules, task cards, workflow docs, cost-card templates, and sanitized examples.
- `private-vault`: real ASINs, SKU details, cost ledgers, reports, account context, decision logs, screenshots, ERP notes, and local paths.

Never mix private-vault content into git-safe-vault.

## Allowed In Git-safe Vault

- README and public entry files.
- `.qianlima/README.md`.
- `.qianlima/WORKSPACE_INDEX.md`.
- Workflow and task-card definitions.
- Public rules and templates.
- Cost-card template and public usage examples.
- Sanitized docs that contain no real account, ASIN, customer, token, cost ledger, or local path.

## Forbidden In Git-safe Vault

- `.qianlima/work.ws`.
- `.qianlima/data-sources.yaml`.
- `.qianlima/user-preferences.yaml`.
- `.qianlima/usage-ledger/`.
- `.qianlima/logs/`.
- `.qianlima/reports/`.
- `.qianlima/run-traces/`.
- Screenshots and exports from private systems.
- Real ASIN, SKU, customer, token, order, cost, or account data.
- Local machine paths.

## Note Metadata

Each exported note should include YAML frontmatter:

```yaml
---
qianlima_version: v2.6.6
source: git-safe
private_data: false
cost_visible: true
risk_level: low
---
```

## Linking Rules

- Use MOC files to link workflows, rules, agent entrypoints, and cost-saving docs.
- Preserve source filenames in links when possible.
- Do not rewrite operational rules without citing the source file.
- Mark missing private data as `pending verification`.

## Review Checklist

- No private data.
- Source file is traceable.
- Cost card is retained when relevant.
- High-risk actions remain blocked or confirmation-gated.
- The note can be shared without exposing account or operational secrets.
