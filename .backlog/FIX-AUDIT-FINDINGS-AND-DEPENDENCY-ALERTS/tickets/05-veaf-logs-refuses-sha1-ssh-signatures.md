# 05 — veaf-logs refuses SHA-1 SSH signatures

Status: ✅ done — 2026-09-28

Source: Dependabot alert #62 (low), CVE-2026-44405 / GHSA-r374-rxx8-8654, open on 2026-09-28.

## The alert

`paramiko` up to 4.0.0 accepts the SHA-1 `ssh-rsa` signature algorithm in `rsakey.py`. **No release
fixes it**, so Dependabot can raise no PR, and bumping is not an answer. `paramiko` is an optional
dependency (extra `logs`), used in one place: `veaf_logs/remote.py:_connect`, the SSH/SFTP tail of a
remote `dcs.log`.

## What to do

Refuse SHA-1 at the call site, which paramiko supports: pass
`disabled_algorithms={"pubkeys": ["ssh-rsa"], "keys": ["ssh-rsa"]}` to `client.connect`. RSA keys
keep working through `rsa-sha2-256` / `rsa-sha2-512`; Ed25519 — what `dcs.veaf.org` uses — is
untouched.

## Test

`test/python/veaf_logs/test_remote.py` already drives `_connect` against a fake
`paramiko.SSHClient` (the class around line 398); assert there that
`connect` receives `disabled_algorithms` with `ssh-rsa` in both lists. Then check once by hand
against `dcs.veaf.org` that the remote tail still connects.

## After the merge — David's call

Dismiss alert #62 on GitHub as *"mitigated: SHA-1 disabled at the only call site"*. It stays open
otherwise until paramiko ships a fix, and an alert that stays red for a known reason teaches
everyone to stop reading them.

## Quality ratchet

If `veaf_logs/remote.py` is still under a mypy `ignore_errors` override, this is a mechanical
one-argument edit and does not trigger the obligation to drop it (`CLAUDE.md` §3).
