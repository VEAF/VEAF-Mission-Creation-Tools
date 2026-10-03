# 03 — the tests stop overwriting the user's `veaf-logs` session

Status: ✅ done — 2026-10-03
Type: fix
Files: `test/python/veaf_logs/conftest.py`, `test/python/veaf_logs/test_profiles.py`

## What

Closing a `MainWindow` saves the session at `default_session_path()`, under `%APPDATA%` (or
`~/.config`). The UI tests close their windows and nothing redirected that path, so every `pytest`
run on a developer's machine replaced their `veaf-logs` session with a test journal.

An autouse fixture in the `veaf_logs` conftest points `APPDATA` at the test's `tmp_path`; a test
asserts both the session and the profiles paths land there (red without the fixture).
