# FEAT-LOGS-REMOTE-TAIL — follow a DCS server log over SSH in `veaf-logs`

Status: ✅ done — merged in #1001 on 2026-09-25 · archived 2026-09-29 (tested by David in the GUI and with the built `veaf-logs.exe`)

## Need

The VEAF servers run several DCS instances on one Windows machine (`dcs.veaf.org`, user
`veaf`, one `Saved Games\<name>_server\Logs\dcs.log` per instance). Reading a live server log
today means an RDP session or a hand-typed `ssh … Get-Content -Wait`, with none of the
filters, rules and colouring `veaf-logs` gives on a local `dcs.log`.

`veaf-logs` must open a remote log the way it opens a local one, and follow it live.

## Measured on 2026-09-24 (read-only, `dcs.veaf.org`)

- Key authentication works with `~/.ssh/id_ed25519`, no password; the SFTP subsystem answers
  (OpenSSH Server for Windows enables it by default), paths are `/C:/Users/veaf/Saved Games/…`.
- Six instances: `foothold1`, `foothold2`, `private1`, `private2`, `public1`, `public2`
  (the last had no `dcs.log` at that moment).
- The live logs weigh 0.3–2 MB: DCS starts a fresh file at every launch and archives the previous
  one as `dcs-<date>.log`, so there is no need for a "start from the last N MB" option.

## Design

- **Byte source, not a stream.** The viewer reads bytes by offset through `Buffer`
  (`veaf_logs/buffer.py`) and only asks `LogSource` for rotation checks and new bytes. A remote
  source therefore needs random access — SFTP `stat` + `open/seek/read` — not a shell `tail`.
- **Local mirror.** The rendering reads the buffer for every displayed line, concurrently with
  the initial indexing thread. `SftpMirrorBuffer.refresh()` does one `stat` and appends the
  delta to a local temporary file; `slice()` reads that file. One network round-trip per poll,
  local reads everywhere else, thread-safe by construction. Rotation is detected as today: a
  size drop or a rewritten first 512 bytes.
- **No password, ever.** Key file from the config, SSH agent as fallback. Unknown host key:
  accept-and-remember dialog on first connection, then the standard `known_hosts`.
- **`veaf-tools.exe` is not involved**: it does not bundle Qt. The feature lives in `veaf-logs`.

## Configuration (`~/veafmct.yaml`)

```yaml
servers:
  veaf:
    host: dcs.veaf.org
    user: veaf
    port: 22                  # optional
    key: ~/.ssh/id_ed25519    # optional: SSH agent and default keys otherwise
    logs:
      private1: C:/Users/veaf/Saved Games/private1_server/Logs/dcs.log
      public1: C:/Users/veaf/Saved Games/public1_server/Logs/dcs.log
```

One machine, several instances: the machine is declared once, each open instance is a tab with its own SSH connection (0.4 s to open, measured; an outage on one tab never disturbs the others).

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | `servers` block in the user config, validated | ✅ |
| 02 | `SftpMirrorBuffer` + `RemoteLogSource` | ✅ |
| 03 | "Open a remote log…" menu, tab, session restore | ✅ |
| 04 | paramiko in the `logs` extra and the spec, LOGS doc | ✅ |

## Measured end to end on 2026-09-24 (`RemoteLogSource` against `dcs.veaf.org`, no UI)

| | |
|---|---|
| Open (connect + mirror 573 KB) | 1.6 s |
| Poll, nothing new | 25 ms |
| Poll, 7 new lines | 130 ms |
| Lines received in 6 s of `private1` | 13 |
| Stopped instance (`public2`) | `RemoteFileMissing`, connection kept |

## Definition of done

- Opening `veaf › private1` from the menu shows the live log of `dcs.veaf.org`, filters and rules
  apply, the tab survives a restart of `veaf-logs`, and a DCS restart on the server (log rotation)
  restarts the tab from the new file.
- No credential is read, prompted for or stored by the tool.
- Unit tests against a fake SFTP client; `veaf-logs.exe` still builds with the spec.

## Tickets, in full

## 01 — `servers` block in the user config

Status: ✅ done — awaiting the manual test in `veaf-logs` against `dcs.veaf.org`
Type: feat
Files: `src/python/veaf-tools/veaf_libs/user_config.py`, `test/python/test_user_config.py`

### What

Read and validate a `servers:` mapping from `~/veafmct.yaml`: per server `host` (required),
`user` (required), `port` (default 22), `key` (optional path, `~` expanded), `logs` (mapping
instance name → remote path, at least one). Expose `get_servers()` returning typed objects.

### Done when

- A valid block parses; a missing `host`, an empty `logs`, a non-mapping value raise a readable
  `ValueError` naming the server.
- No `servers` block → empty list, no error.

## 02 — `SftpMirrorBuffer` and `RemoteLogSource`

Status: ✅ done — awaiting the manual test in `veaf-logs` against `dcs.veaf.org`
Type: feat
Files: `src/python/veaf-tools/veaf_logs/remote.py`, `test/python/test_veaf_logs_remote.py`

### What

- `SftpMirrorBuffer(Buffer)`: `refresh()` stats the remote file, downloads the bytes past the
  mirrored size into a local temporary file; `slice()` reads the local file; `close()` removes it.
  A size drop or a rewritten head resets the mirror.
- `RemoteLogSource`: same contract as `LogSource` (`open`, `buffer`, `check_rotation`, `reopen`,
  `close`, `display_name`, `followable`), built from a server + instance, opening the SSH
  connection lazily with paramiko (key from the config, agent fallback, never a password).
- Network failure during a poll raises `LogUnavailable`, so the tab waits and resumes, as for a
  file missing during rotation.

### Done when

Tests with a fake SFTP client cover: first mirror, delta append, rotation by size drop, rotation
by head rewrite, transient failure, `close()` removing the temporary file.

## 03 — "Open a remote log…" in the UI, session restore

Status: ✅ done — awaiting the manual test in `veaf-logs` against `dcs.veaf.org`
Type: feat
Files: `src/python/veaf-tools/veaf_logs/ui/main_window.py`, `veaf_logs/session.py`,
`test/python/test_veaf_logs_session.py`

### What

- Menu entry listing `server › instance` pairs from the config; a message when none is configured
  pointing at the doc.
- Tab named `server:instance`, tooltip `user@host:path`.
- Remote tabs poll at 1 s instead of 400 ms.
- `OpenFile` gains an optional `remote` field (`"server/instance"`); `existing_files()` keeps
  remote entries; restore reopens them.
- Unknown host key: accept-and-remember dialog, refusal closes nothing else.

### Done when

Session round-trip test with a remote entry; manual test against `dcs.veaf.org`.

## 04 — packaging and documentation

Status: ✅ done — awaiting the manual test in `veaf-logs` against `dcs.veaf.org`
Type: chore/docs
Files: `pyproject.toml`, `veaf-logs.spec`, `doc/mission-maker/LOGS.md`, `LOGS.en.md`, `CHANGELOG.md`

### What

- `paramiko` added to the `logs` extra (optional, like PySide6); the spec keeps it in the exe.
- LOGS doc: a "remote log" section with the config block, the key-only authentication rule, and
  the server-side setup on Windows (OpenSSH Server optional feature; an administrator account's
  keys go to `C:\ProgramData\ssh\administrators_authorized_keys`, not the profile).
- Changelog entry under `[Unreleased]`.
