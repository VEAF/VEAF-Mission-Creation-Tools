# 01 — filter pull requests in a job, not at the trigger

Status: ✅ done — merged in #1053; the 11 required checks are on `develop` (verified 2026-10-03)

See the PRD. Files: `veaf_build/ci_path_gate.py`, `.github/workflows/{python-quality,docs-check,support-bot-ci}.yml`,
`test/python/test_ci_trigger_paths.py`, `test/python/veaf_build/test_ci_path_gate.py`,
`doc/developer/GUIDE.md` / `.en.md`.
