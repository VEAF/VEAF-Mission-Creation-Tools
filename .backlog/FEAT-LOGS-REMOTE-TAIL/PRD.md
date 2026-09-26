# FEAT-LOGS-REMOTE-TAIL — follow a DCS server log over SSH in `veaf-logs`

Status: ✅ done — merged in #1001 on 2026-09-25 (tested by David in the GUI and with the built `veaf-logs.exe`)

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
| [01](tickets/01-servers-config.md) | `servers` block in the user config, validated | ✅ |
| [02](tickets/02-sftp-mirror-buffer.md) | `SftpMirrorBuffer` + `RemoteLogSource` | ✅ |
| [03](tickets/03-open-remote-ui.md) | "Open a remote log…" menu, tab, session restore | ✅ |
| [04](tickets/04-packaging-and-doc.md) | paramiko in the `logs` extra and the spec, LOGS doc | ✅ |

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
