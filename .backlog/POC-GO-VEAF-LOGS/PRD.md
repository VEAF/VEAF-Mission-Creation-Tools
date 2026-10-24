# POC-GO-VEAF-LOGS — can a Go rewrite of veaf-logs keep the promise of a small, fast native binary?

Status: ✅ done — 2026-10-24

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
| 01 | [Baseline measurements of the Python viewer](tickets/01-baseline.md) | ✅ |
| 02 | [Go core and parity proof](tickets/02-core-and-parity.md) | ✅ |
| 03 | [Minimal UI and toolkit ADR](tickets/03-ui-and-adr.md) | ✅ |
| 04 | [Remote journal over SFTP](tickets/04-sftp.md) | ✅ |
