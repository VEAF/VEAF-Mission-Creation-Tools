# POC-GO-VEAF-LOGS — can a Go rewrite of veaf-logs keep the promise of a small, fast native binary?

Status: ✅ done — 2026-10-24 · archived 2026-11-24

Origin: David, 2026-10-23.
He wants a real native binary for VMCT.
Rewriting all of `veaf-tools` (~84 000 lines of Python, ~81 000 of tests) is out of proportion for an unproven bet, so the bet is placed on `veaf-logs` alone: ~4 100 lines of core Python (about 6 500 with the Qt window), a PySide6 + paramiko executable built by PyInstaller.
The Lua runtime (170 000 lines) stays Lua whatever the answer is.

## Question

Does Go deliver a smaller executable, a faster start and **the same result** as the Python viewer?
"We do not do it" is a valid outcome.

## Scope

- A new, isolated module `src/go/veaf-logs/`. No change to the Python code, `release.yml` or any release pipeline.
- Core without UI: `rules.json` (reused as is — it is language-independent), header formats, the compact index, classification of every line.
- A parity proof against the Python implementation, line by line, on a corpus of logs.
- A minimal UI: virtualised list (a journal can hold millions of lines), colours by level, search, follow (tail) with rotation detection.
- If time allows: remote journal over SFTP, same local-mirror model.
- Out of scope: `analysis`, `report`, `proposals`, `excerpt`.

## Measured baseline (Python, 2026-10-23, DAVID-BUREAU)

| Measure | Python |
|---|---|
| `veaf-logs.exe` (`veaf-build build-logs`, 6.31.4) | 47.2 MB |
| Window visible after launch | 2.1 s (1.87–2.20 s over 5 launches, warm disk cache) |
| Indexing a 130 MB / 954 086-entry journal, headless | 13.2–13.6 s |

## Decision pending

The UI toolkit decides the binary weight: it is decided by measurement and recorded in an ADR (ticket 03).

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Baseline measurements of the Python viewer](POC-GO-VEAF-LOGS.md) | ✅ |
| 02 | [Go core and parity proof](POC-GO-VEAF-LOGS.md) | ✅ |
| 03 | [Minimal UI and toolkit ADR](POC-GO-VEAF-LOGS.md) | ✅ |
| 04 | [Remote journal over SFTP](POC-GO-VEAF-LOGS.md) | ✅ |

## Tickets, in full

## 01 — baseline measurements of the Python viewer

Status: ✅ done — 2026-10-23
Type: investigate

Measure the existing executable so that the PoC has a before/after: size of `veaf-logs.exe`, time until the window is visible, time to index a ~1 M-line journal.
Numbers are in the PRD.

## 02 — Go core and parity proof

Status: ✅ done — 2026-10-23
Type: feature

Port `rules`, the header formats, the compact index (`store`) and the file buffer (read by offset, never held open) to Go in `src/go/veaf-logs/`, loading the unchanged `rules.json`.

Done when a Go test compares, entry by entry, level, source, label, module, noise families, timestamp, subsystem, message and continuation count with a golden dump produced by the Python implementation, on a corpus covering the five header formats, and when the counters per level, source and noise family match too.
The same dump is also compared on real `dcs.log` files.

## 03 — minimal UI and toolkit ADR

Status: ✅ done — 2026-10-24
Type: feature

A virtualised list with colours by level, search, and follow with rotation detection.
Candidate toolkits (Gio, Fyne, Wails) are compared on executable size, cold start, scrolling over 1 M lines and code effort; the choice and the numbers go in an ADR under `docs/adr/`.

Done with Gio ([ADR 0021](../../docs/adr/0021-gio-for-the-go-veaf-logs-proof-of-concept.md)): list, colours by level, search, follow with rotation detection.

## 04 — remote journal over SFTP (if time allows)

Status: ✅ done — 2026-10-24
Type: feature

Read a remote journal through a local mirror, key or agent authentication, with `golang.org/x/crypto/ssh` and `github.com/pkg/sftp`, as `remote.py` does.

Done: `internal/logcore/remote.go` (mirror, rotation, bounded download, reconnection with a delay) and `internal/sshlog` (key/agent authentication, `known_hosts` check, the `servers` block of `~/veafmct.yaml`), tested against an in-process SSH + SFTP server and, read-only, against dcs.veaf.org (50 236 entries of `veaf/private1` in 1.5 s). `veaf-logs --remote SERVER/INSTANCE`, `--servers` to list them.
Not done: a host-key prompt (an unknown host is refused with the `ssh` command to run once), the Windows OpenSSH agent pipe, passphrase-protected keys outside an agent.
