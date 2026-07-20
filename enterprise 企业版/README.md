# Beijixing Enterprise Edition

The Enterprise Edition is a Beijixing product profile over the shared Qianlima core.
It does not copy or fork the main Harness. It reads the shared contracts from
the parent workspace and adds enterprise identity, approval, audit, Runner,
and deployment settings here.

## Start

Windows:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File '.\enterprise 企业版\start-enterprise.ps1'
```

Administrator deployment on a new Windows machine:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File '.\enterprise 企业版\install-enterprise-environment.ps1' -Install -AcceptDockerDesktopLicense
```

macOS/Linux:

```bash
bash 'enterprise 企业版/start-enterprise.sh'
```

Administrator deployment on a new macOS machine:

```bash
bash 'enterprise 企业版/install-enterprise-environment.sh' --install --accept-docker-license
```

Every Enterprise start runs the mandatory environment gate before loading the
shared core. Missing Docker, daemon health, the approved local image, Runner
registration, or platform virtualization blocks startup with remediation
details. Installation is a separate administrator action and never happens
through an ordinary user start.

## Profiles

- `edition.yaml`: Enterprise capability and deployment profile.
- `config.example.yaml`: Git-safe tenant, identity, audit, and credential references.
- `trust-policy.yaml`: Per-action continuous trust evaluation and shrink/freeze responses.
- `governance-adapter.yaml`: One adapter contract for runtime, A2A, MCP, files, network, memory, and audit interception.
- `event-contract.json`: Append-only task, Grant, Artifact, verification, revocation, and freeze events.
- `deployment-policy.yaml`: Required managed runtime and fail-closed startup policy.
- `task-level-policy.json`: Enterprise-specific L0-L4 meanings and escalation rules.
- `invoke-enterprise-task-gate.ps1`: Mechanical enterprise task classification and authorization gate.
- `test-enterprise-task-levels.ps1`: Personal-versus-enterprise risk regression suite.
- `organization-role-templates.json`: Beginner-friendly owner, manager, employee, and security role templates.
- `new-enterprise-organization.ps1`: Guided company, department, and initial administrator setup.
- `组织与人员设置指南.md`: Plain-language onboarding guide for owners and employees.
- `onboarding-text.zh-CN.json`: Chinese wizard text kept outside PowerShell source for Windows 5.1 compatibility.
- `connection-policy.json`: Unified NAS, cloud drive, API, database, event, and download connection policy.
- `data-connections.example.json`: Disabled-by-default connection registry examples.
- `invoke-enterprise-connection-gate.ps1`: Mechanical connection, data class, network zone, and L4 gate.
- `test-enterprise-connections.ps1`: Connection policy regression suite without network access.
- `approval-routing-policy.json`: Responsibility, threshold, and batch approval routing.
- `five-view-task-contract.json`: Business, outcome, failure, core-issue, and handling views over one task.
- `new-five-view-task.ps1`: Creates a five-view task brief without executing anything.
- `commerce-deliverable-contract.json`: Profitability, title, main image, five bullets, and long-description outcome contract.
- `new-commerce-deliverable-pack.ps1`: Creates a pending product deliverable pack without uploading or changing price.
- `commerce-operating-model.json`: Reports, plans, profit settlement, sourcing, logistics, inventory, traffic, ads, promotions, after-sales, and review lifecycle.
- `compliance-mcp-policy.json`: Tax, customs, and product-compliance MCP read/write separation.
- `invoke-compliance-mcp-gate.ps1`: Mechanical compliance MCP gate; it never calls MCP itself.
- `lingxing-business-architecture.json`: Official-document-backed Lingxing business-domain map.
- `lingxing-mcp-adapter-contract.json`: Reserved read-first MCP interface and normalized receipt contract.
- `lingxing-mcp-registry.example.json`: Disabled-by-default Lingxing MCP registration example.
- `invoke-lingxing-mcp-gate.ps1`: Mechanical future Lingxing MCP gate; it opens no network connection.
- `enterprise-mcp-platform-contract.json`: Vendor-neutral MCP governance for all enterprise tool and data servers.
- `obsidian-connector-contract.json`: Reserved Obsidian knowledge connector; selected Markdown reads only by default, with Vault references instead of raw host paths.
- `obsidian-connector-registry.example.json`: Disabled-by-default Vault registration example.
- `invoke-obsidian-connector-gate.ps1`: Offline admission gate for note scope, file type, task Grant, and L4 write separation.
- `../.qianlima/enterprise-data-admission-contract.json`: Policy-first evidence admission; identity and Grant checks precede ranking and Top-K.
- `../.qianlima/scripts/invoke-enterprise-data-admission.ps1`: Produces minimum sanitized Evidence Packs; external Agents receive no knowledge-search capability.
- `mcp-server-registry.example.json`: Disabled-by-default generic MCP Server Passport example.
- `invoke-enterprise-mcp-gate.ps1`: Generic MCP admission, version, data, budget, and write gate.
- `direct-mcp-session-contract.json`: Business-approved low-latency Agent-to-MCP session contract.
- `invoke-direct-mcp-session-gate.ps1`: Validates the short-lived session while keeping the local Connector inline.
- `employee-lifecycle-policy.json`: Joiner, Mover, Leaver, suspension, and emergency isolation policy.
- `file-organization-policy.json`: Organizes new artifacts by business, department, L0-L4, month, task, and artifact type.
- `new-enterprise-artifact-location.ps1`: Generates a governed location without moving or creating files.
- `review-compounding-policy.json`: Turns verified reviews into candidates; production promotion remains replayed, verified, and human-approved.
- `new-enterprise-review.ps1`: Creates a five-view review and lesson candidate with no production authority.
- `踩坑日志模板.md`: Plain-language pitfall and prevention log for teams.
- `test-file-review-compounding.ps1`: Offline regression for organization, review, and non-mutation boundaries.
- `deployment-mode-policy.json`: E1-E4 matrix for enterprise/BYOK API and fixed/employee-selected Agents.
- `select-enterprise-deployment-mode.ps1`: Two-question beginner selector; it grants no runtime permissions.
- `test-deployment-modes.ps1`: Offline regression for all four mappings and their hard boundaries.
- `../.qianlima/model-portfolio.yaml`: Model Passport fields, routing tiers, evidence metrics, and trust boundaries.
- `../.qianlima/fusion-plan-schema.yaml`: Evidence-first multi-model Fusion Plan contract.
- `../.qianlima/scripts/validate-fusion-plan.ps1`: Validates risk, independence, data, verifier, and human-approval requirements.
- `../.qianlima/scripts/test-model-fusion.ps1`: Offline regression for L0-L4 fusion admission.
- `new-employee-lifecycle-request.ps1`: Creates a lifecycle request without changing identity or access.
- `invoke-employee-lifecycle-gate.ps1`: Produces the mandatory revoke, handover, and recovery action plan.
- `员工增减与调岗指南.md`: Beginner guide for managers, HR, and employees.
- `test-enterprise-environment.ps1`: Read-only machine deployment preflight.
- `install-enterprise-environment.ps1`: Explicit Windows administrator deployment entrypoint.
- `install-enterprise-environment.sh`: Explicit macOS administrator deployment entrypoint.
- `start-enterprise.ps1`: Windows and PowerShell entrypoint.
- `start-enterprise.sh`: macOS/Linux launcher.
- `test-enterprise-profile.ps1`: profile contract regression test.

Real execution remains disabled until a registered Runner has a verified,
task-bound Sandbox Attestation and a separate human enablement decision.
Passing the environment gate proves deployment readiness only; it does not
grant Agent, network, MCP, file, or business-system permissions.

Enterprise L0-L4 is intentionally stricter than Personal L0-L4. Enterprise
levels include organizational scope, employee and device identity, project and
cost-center ownership, Agent trust, independent verification, and separation
of duties. A Personal classification is never accepted as Enterprise authority.

For first-time setup, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File '.\enterprise 企业版\new-enterprise-organization.ps1'
```

The wizard writes private organization configuration under
`.qianlima/local-data/enterprise/` and refuses to overwrite an existing file.

## Role manuals

- `企业版分层使用说明书.md`: Start here and choose a role.
- `说明书-老板.md`: Results, major risk, thresholds, and governance decisions.
- `说明书-业务负责人.md`: Projects, employee scope, MCP approval, and handling ownership.
- `说明书-员工.md`: Natural-language tasks, Agent/MCP use, outcomes, and assigned actions.

Qianlima Enterprise uses a hybrid placement model: the Broker and audit plane
run centrally in an enterprise-controlled environment; employee computers run
only the managed Connector, sandbox Runner, and local Agent. Data systems stay
in their existing zones and are reached only through configured Broker
connections. The central Broker is not exposed as a public general Agent.
