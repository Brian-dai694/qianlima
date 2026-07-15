# Harness Evolution

This directory separates candidate harness changes from the approved runtime.
Production tasks use only approved rules. A candidate is evidence for a possible
change, not permission to modify production files.

1. Record a sanitized failure, correction, or improvement hypothesis.
2. Create one scoped candidate under `candidates/`.
3. Replay the candidate against the four suites in `eval-cases/`.
4. Record the result in `promotion-log.jsonl`.
5. A human approves or rejects the candidate before any production change.

Do not place private reports, source data, credentials, customer content, or
browser exports in this directory.
