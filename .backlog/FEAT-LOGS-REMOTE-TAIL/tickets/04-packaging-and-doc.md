# 04 — packaging and documentation

Status: ✅ done — awaiting the manual test in `veaf-logs` against `dcs.veaf.org`
Type: chore/docs
Files: `pyproject.toml`, `veaf-logs.spec`, `doc/mission-maker/LOGS.md`, `LOGS.en.md`, `CHANGELOG.md`

## What

- `paramiko` added to the `logs` extra (optional, like PySide6); the spec keeps it in the exe.
- LOGS doc: a "remote log" section with the config block, the key-only authentication rule, and
  the server-side setup on Windows (OpenSSH Server optional feature; an administrator account's
  keys go to `C:\ProgramData\ssh\administrators_authorized_keys`, not the profile).
- Changelog entry under `[Unreleased]`.
