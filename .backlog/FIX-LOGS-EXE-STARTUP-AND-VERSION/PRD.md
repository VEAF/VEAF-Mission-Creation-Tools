# FIX-LOGS-EXE-STARTUP-AND-VERSION — `veaf-logs.exe` takes 14 s to open and reports no version

Status: ⏸ paused — filed 2026-09-30; David: **pick it up after the 6.26.0 release**, not before.

## Origin

Found while closing [CHORE-LOGS-EXE-TRIM](../archive/CHORE-LOGS-EXE-TRIM.md) on 2026-09-30.

## Measured / read

| | |
|---|---|
| Cold start, launch → window visible, median (Windows 11, DAVID-BUREAU) | 14.78 s at 68.7 MB, **14.23 s at 48.0 MB** |
| `tool.version` in the report built by `veaf-logs` | most likely `unknown` — read from the code, **not measured in a running exe** |

Removing 20 MB saved 0.5 s: the 14 s are not the archive size.

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| [01](tickets/01-cold-start.md) | Find where the 14 s go, then cut them | ⏸ |
| [02](tickets/02-report-version.md) | Make the `veaf-logs` report carry the real version | ⏸ |

## Definition of done

- The cold start is measured with the method of CHORE-LOGS-EXE-TRIM, before and after, and the
  numbers are written here; the cause is named by a measurement, not assumed.
- A release-built `veaf-logs.exe` puts the shipped version in `tool.version`, checked in the exe.
