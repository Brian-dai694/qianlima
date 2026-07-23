# A2A Adoption Roadmap

## Decision

Qianlima treats A2A as an interoperability contract for independent agents. It remains the policy and verification broker. Codex remains the primary interactive runtime.

## Phase 0: Internal Contract

Status: active

- Use `agent-cards.yaml` for capability boundaries.
- Use `work-order-schema.yaml` for delegated work.
- Use `a2a-compatibility.yaml` for task, artifact, and state mappings.
- Keep all delegation local, read-only, and replayable.

Exit gate: a task envelope can be generated, independently verified, and traced without exposing raw business data.

## Phase 1: Local Mock Exchange

- Implement a local mock client and mock remote agent.
- Permit only sanitized research or knowledge-digest artifacts.
- Verify task immutability, state translation, artifact hashes, timeout handling, and context isolation.

Exit gate: replay cases show no cross-context artifact access and no L4 authority leakage.

## Phase 2: Governed A2A Client

- Begin with `a2a-client-gateway-policy.yaml` and `scripts/preflight-a2a-client.ps1`; preflight is dry-run only and defaults to deny.
- Allow one explicitly allowlisted, read-only remote agent only after a separate approval enables network dispatch.
- Insert a Qianlima gateway before dispatch and after artifact return.
- Require protocol-version negotiation, source classification, a manager-owned verifier, and a complete receipt.

Exit gate: security review, latency budget, failure drill, and human approval pass.

## Phase 3: External Service Exposure

Not scheduled. This requires separate approval for authentication, tenant isolation, network policy, incident response, retention, monitoring, and external-agent trust.

## Permanent Rules

- An A2A Agent Card is not a permission grant.
- External agents never receive L4 execution authority.
- Finished tasks are immutable; refinements create a new task referencing prior artifacts.
- A2A transport does not replace MCP tools, risk rules, command safety, or human confirmation.
