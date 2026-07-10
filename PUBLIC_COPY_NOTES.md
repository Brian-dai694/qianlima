# Public Copy Notes

This repository is a sanitized public copy of the Qianlima workspace.

Do not commit:

- API keys, tokens, passwords, cookies, or credentials
- real customer names, emails, phone numbers, addresses, or contracts
- real account IDs, ad console exports, ERP exports, or marketplace backend dumps
- private cost ledgers, usage ledgers, decision logs, screenshots, or reports
- local machine paths or user home directories

Use `.qianlima/data-sources.example.yaml` and `.qianlima/work.example.ws` as templates for private local configuration.

Before publishing, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\.qianlima\scripts\verify-qianlima.ps1"
```

Automation added:

- `.github/workflows/qianlima-verify.yml` runs startup, strict verification, and runtime safety checks.
- `.qianlima/scripts/new-usage-record.ps1` creates ignored local usage ledgers.
- `.qianlima/scripts/new-decision-log-entry.ps1` creates ignored decision logs and requires confirmation refs for high-risk actions.