# Compression Attack Defense

Version: v2.6.1
Date: 2026-07-09

This rule adapts the COMA / Comattack risk model to Qianlima. It treats context compression, summary handoff, and multi-agent memory folding as security-sensitive operations.

## Risk Model

Compression is not a neutral transformation. A hostile or malformed source can cause a summary to omit constraints, preserve misleading facts, invert preferences, or drop safety rules. Any downstream recommendation that relies only on compressed context can be wrong even when the original source was available.

## Applies When

- A task reads more than five files.
- A file is summarized before use.
- A GUI or web workflow uses folded memory.
- A subagent receives a summary instead of the original source.
- A recommendation affects bid, budget, price, purchase, listing content, external send, or write-back.

## Required Gates

1. Preserve source references.
   Every compressed summary must include source path, source section, timestamp or version when available, and confidence.

2. Preserve constraints.
   The summary must explicitly keep user constraints, risk rules, forbidden operations, data freshness limits, and open questions.

3. Flag compression-sensitive conclusions.
   If a conclusion depends on omitted raw content, mark it as pending verification.

4. Reload before high-risk action.
   Do not execute or recommend high-risk action from compressed context alone. Reload the original source section or ask the user to confirm.

5. Run adversarial summary check for important decisions.
   Before high-impact decisions, ask: "What critical fact could have been dropped, inverted, or over-weighted by compression?"

6. Keep refusal and permission rules uncompressed.
   Risk rules, privacy rules, and user confirmations should be loaded directly when they control execution.

## Failure Signals

- The summary contains recommendations but no source sections.
- A constraint appears in the original source but not in the summary.
- Two summaries of the same source disagree on core facts.
- A subagent acts on a summary without checking risk rules.
- A high-risk action is justified only by a compressed memory fold.

## Required Response Behavior

When compression risk is present, the Agent must include:

- Data source
- Compression level
- Facts preserved
- Facts omitted or pending verification
- Whether source reload is required before action

## Source References

- XPolicyLab/XPolicyLab: policy adapter and server-client separation pattern.
- zsLiu2003/Comattack: COMA threat model for compression as an attack surface.
