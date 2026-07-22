# Harness Evolution

This directory separates candidate harness changes from the approved runtime.
Production tasks use only approved rules. A candidate is evidence for a possible
change, not permission to modify production files.

1. Record a sanitized failure, correction, or improvement hypothesis.
2. Create one scoped candidate under `candidates/`.
3. Validate the structured contract with `scripts/validate-improvement-candidate.ps1`.
4. Replay the candidate against the four suites in `eval-cases/`, plus latency and L4 safety gates.
5. Record the result in `promotion-log.jsonl`.
6. A separate verifier checks the candidate; low-risk Skill candidates may continue through automatic release.
7. `scripts/promote-improvement-candidate.ps1` may emit `promotion_candidate` only. A human release creates a new production revision; no candidate edits production automatically.

## Skill self-evolution manager

Use `scripts/invoke-skill-self-evolution.ps1` to enforce the ordered management
loop. The manager appends metadata-only events to
`skill-self-evolution-events.jsonl`; it does not edit a production Skill or
grant a permission.

```text
record_feedback
-> collect_evidence
-> abstract_rule
-> create_patch
-> validate
-> auto_release (low risk only)
-> rollback (when required)
```

Every transition is fail-closed. Feedback must be a sanitized record, evidence
must be inside `eval-cases`, candidates must pass the existing independent
validator, and low-risk release must have no permission or attack-surface
change. No approval prompt is shown for this path. Failed validation or any
high-risk change freezes the candidate and keeps the prior version active.
Original feedback, evaluation cases, and candidate files are never overwritten
by the manager.

Run the regression test with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-skill-self-evolution.ps1
```

Do not place private reports, source data, credentials, customer content, or
browser exports in this directory.
