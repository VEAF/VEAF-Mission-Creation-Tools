# 02 — `SftpMirrorBuffer` and `RemoteLogSource`

Status: ✅ done — awaiting the manual test in `veaf-logs` against `dcs.veaf.org`
Type: feat
Files: `src/python/veaf-tools/veaf_logs/remote.py`, `test/python/test_veaf_logs_remote.py`

## What

- `SftpMirrorBuffer(Buffer)`: `refresh()` stats the remote file, downloads the bytes past the
  mirrored size into a local temporary file; `slice()` reads the local file; `close()` removes it.
  A size drop or a rewritten head resets the mirror.
- `RemoteLogSource`: same contract as `LogSource` (`open`, `buffer`, `check_rotation`, `reopen`,
  `close`, `display_name`, `followable`), built from a server + instance, opening the SSH
  connection lazily with paramiko (key from the config, agent fallback, never a password).
- Network failure during a poll raises `LogUnavailable`, so the tab waits and resumes, as for a
  file missing during rotation.

## Done when

Tests with a fake SFTP client cover: first mirror, delta append, rotation by size drop, rotation
by head rewrite, transient failure, `close()` removing the temporary file.
