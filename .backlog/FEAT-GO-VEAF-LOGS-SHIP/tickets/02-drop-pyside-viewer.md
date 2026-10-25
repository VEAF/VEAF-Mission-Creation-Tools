# 02 — The PySide6 viewer leaves

Status: ⬜ ready

Removes what only the Python window used, per the PRD's questions 1 and 3: `veaf_logs/ui/`, the entry point, `veaf-logs.spec`, PySide6 (and `paramiko` if nothing else imports it) from the `logs` extra, their tests, and the CI steps that install Qt's system libraries for them (`python-quality.yml`).
Keeps the core the support bot imports and the Go goldens are generated from.
The coverage gate is re-measured after the removal; it may only go up (CLAUDE.md, quality ratchet).
