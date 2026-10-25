# FEAT-GO-VEAF-LOGS-SHIP — the Go `veaf-logs` becomes the shipped one

Status: ✅ done — 2026-10-25 (#1190)

Origin: David, 2026-10-25, closing [FEAT-GO-VEAF-LOGS-ISOFUNCTIONAL](../FEAT-GO-VEAF-LOGS-ISOFUNCTIONAL/PRD.md): "veaf-logs reste en Go, mais le reste continue en Python (trop lourd de convertir)".
Recorded in [ADR 0023](../../docs/adr/0023-veaf-logs-in-go-the-rest-in-python.md).

## Goal

The `veaf-logs.exe` a release publishes is the Go build of `src/go/veaf-logs/`; the PySide6 viewer is no longer built nor shipped.
Nothing else moves to Go.

## What exists today (read on `develop` at `3060ba38`)

- `release.yml` builds `veaf-logs.exe` on its Windows job with PyInstaller from `veaf-logs.spec` (`veaf-build build-logs`, `veaf_build/worker.py` `build_veaf_logs`), and uploads it to the release and to `published-latest`.
- `pyproject.toml` packages `veaf_logs` with its `rules.json` and icon, and carries the `logs` extra (`PySide6-Essentials`, `paramiko`) for the viewer only.
- The support bot imports the Python core: `veaf_logs.rules`, `store`, `buffer`, `profiles`, `excerpt`, `catalogue` (`services/support-bot/veaf_support_bot/toolkit.py`).
- The Go CI regenerates its goldens from the Python modules and fails when they drift (`src/go/veaf-logs/testdata/gen_golden.py`, `gen_analysis_golden.py`).
- `veaf-tools` updates itself and its siblings from the release assets; how it finds `veaf-logs.exe` is to be read before ticket 01.

## Open questions, with the default recommendation

1. **Which Python stays.** *Default*: keep the non-Qt core the support bot imports, and drop `veaf_logs/ui/`, `__main__.py`, the `logs` extra's PySide6 and their tests.
2. **Which side is the reference.** *Default*: `rules.json` stays one file, read by both; the Python core stays the parity reference for as long as the support bot uses it, so the Go CI's drift check keeps its meaning.
3. **`paramiko`.** *Default*: drops with PySide6 if nothing else imports it — to check.

All three taken as recommended. What stays is what the support bot or the goldens import: `buffer`, `store`, `rules` (+ `rules.json`), `parser`, `filters`, `profiles`, `excerpt`, `catalogue`, `proposals`, `analysis`, `report`, `worker_client`.
What left with the window, nothing else importing it: `ui/`, `__main__.py`, `session.py`, `appearance.py`, `tailer.py`, `remote.py`, and with `remote.py` the last user of `paramiko`.
The icon moved to `src/go/veaf-logs/cmd/veaf-logs/`, where `go:generate` reads it.

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | [The release builds and publishes the Go `veaf-logs.exe`](tickets/01-release-builds-go.md) | ✅ |
| 02 | [The PySide6 viewer leaves](tickets/02-drop-pyside-viewer.md) | ✅ |
| 03 | [Docs and support bot say it is the Go viewer](tickets/03-docs.md) | ✅ |

## What was found and measured

- **The updater never handled `veaf-logs`.** `veaf-tools-updater` replaces `veaf-tools.exe` and itself, nothing else (`veaf-tools-updater.py`, `platform_assets`); `veaf-logs.exe` is taken by hand from the release. Ticket 01's "the updater finds it" holds by the asset name staying `veaf-logs-<version>.exe`, on the versioned release and on `published-latest` (`test_release_mirrors_every_asset.py`).
- **`veaf-logs-exe-smoke` is a required check on `develop`**: removing the PyInstaller job would have left every pull request waiting on it. The job keeps its name and now builds the viewer as the release does — `veaf-build build-logs` on Windows — then checks the version is in the executable and that `--smoke` opens a journal.
- **Release dry run, 2026-10-25**: `poetry run veaf-build build-logs --version 0.0.0-dryrun` gives a 13.4 MB `dist/veaf-logs.exe` carrying `0.0.0-dryrun`; `--smoke` on `testdata/corpus/mixed.log` exits 0, on a missing journal exits 2.
- **Coverage after the removal**: 90.25 % (7 108 tests), the gate stays at 89.0 % — within the two points CLAUDE.md allows. Without PySide6 installed, the local run no longer falls under the gate.
- **The user doc said `%APPDATA%\veaf-logs`** for the profiles and the session; both viewers use `%APPDATA%\veaf_logs`. Fixed with the rest of the page, whose large-journal figures are now the Go viewer's (ISOFUNCTIONAL, J2).
