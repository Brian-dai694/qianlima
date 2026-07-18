# Harness Evolution

This directory separates candidate harness changes from the approved runtime.
Production tasks use only approved rules. A candidate is evidence for a possible
change, not permission to modify production files.

1. Record a sanitized failure, correction, or improvement hypothesis.
2. Create one scoped candidate under `candidates/`.
3. Validate the structured contract with `scripts/validate-improvement-candidate.ps1`.
4. Replay the candidate against the four suites in `eval-cases/`, plus latency and L4 safety gates.
5. Record the result in `promotion-log.jsonl`.
6. A separate verifier checks the candidate; permission expansion also needs an explicit human approval reference.
7. `scripts/promote-improvement-candidate.ps1` may emit `promotion_candidate` only. A human release creates a new production revision; no candidate edits production automatically.

Do not place private reports, source data, credentials, customer content, or
browser exports in this directory.
