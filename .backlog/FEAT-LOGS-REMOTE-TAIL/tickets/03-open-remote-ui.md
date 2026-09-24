# 03 — "Open a remote log…" in the UI, session restore

Status: ✅ done — awaiting the manual test in `veaf-logs` against `dcs.veaf.org`
Type: feat
Files: `src/python/veaf-tools/veaf_logs/ui/main_window.py`, `veaf_logs/session.py`,
`test/python/test_veaf_logs_session.py`

## What

- Menu entry listing `server › instance` pairs from the config; a message when none is configured
  pointing at the doc.
- Tab named `server:instance`, tooltip `user@host:path`.
- Remote tabs poll at 1 s instead of 400 ms.
- `OpenFile` gains an optional `remote` field (`"server/instance"`); `existing_files()` keeps
  remote entries; restore reopens them.
- Unknown host key: accept-and-remember dialog, refusal closes nothing else.

## Done when

Session round-trip test with a remote entry; manual test against `dcs.veaf.org`.
