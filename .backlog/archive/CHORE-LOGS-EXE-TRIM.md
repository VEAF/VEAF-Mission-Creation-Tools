# CHORE-LOGS-EXE-TRIM — `veaf-logs.exe` carries the MCP server and mypy it never runs

Status: ✅ done — filed 2026-09-25, done 2026-09-30 · archived 2026-10-03

## Origin

Building `veaf-logs.exe` for FEAT-LOGS-REMOTE-TAIL (`poetry run pyinstaller --noconfirm veaf-logs.spec`,
PyInstaller 6.22.3) on 2026-09-25.

## Measured

| | |
|---|---|
| `dist/veaf-logs.exe` | 68.6 MB (64.4 MB for the previous build of 2026-08-31) |
| Archive entries matching `mypy` or `mcp` (`pyi-archive_viewer -l dist/veaf-logs.exe`) | 73 |
| Also in the module graph (`build/veaf-logs/warn-veaf-logs.txt`) | `uvicorn`, `starlette`, `mcp.server.*`, `veaf_mission_mcp.catalog`, `veaf_libs.mission_validator`, `mission_tools.miz_tools`, `PIL`, `geopy`, `avwx`, `setuptools` |

The +4.2 MB of the new build is consistent with `paramiko` + `cryptography` alone; the payload
above was most likely already there — it just had never been looked at.

## Cause (hypothesis as filed)

PyInstaller follows imports statically, delayed and conditional ones included. `veaf_logs/report.py`
imports `veaf_libs.diagnostics`; from there the graph reaches `veaf_libs.i18n`, `veaf_libs.logger`,
`veaf_libs.lua_config_generator`, `veaf_libs.checklists`, `veaf_libs.mission_validator`,
`veaf_mission_mcp.catalog`, the MCP stack, and pydantic's `pydantic.mypy` plugin, which drags `mypy`
(a dev dependency) into a shipped executable. None of it runs in the log viewer.

## Ticket

| # | Ticket | Status |
|---|--------|--------|
| 01 | Cut the chain or exclude the packages, measure before/after | ✅ |

## Definition of done

- `pyi-archive_viewer -l dist/veaf-logs.exe` finds no `mypy`, `mcp`, `uvicorn`, `starlette` entry.
- `paramiko` is still bundled (lazily imported by `veaf_logs/remote.py`; listed in `hiddenimports`).
- Size and cold-start time of the exe measured before and after and written here.
- `poetry run pytest test/python/veaf_logs` green; the exe opens a local `dcs.log` and a remote one.

## Outcome (2026-09-30)

**Confirmed on the xref, with one correction: the viewer does run the collectors.** The report dialog
(`veaf_logs/ui/analysis_view.py`, `_doctor_report`) calls `build_report()`, so `_collect_tool` imported
`veaf_tools.app` — every command, the MCP server — **at run time**, to read one string. Excluding
`veaf_tools` in the spec would have turned all four `tool.*` fields into `unknown` without a word, so
the edge was cut in the code instead. Two edges, two cuts, no exclusion:

| Edge | Chain | Fix |
|---|---|---|
| `diagnostics._collect_tool` | → `veaf_tools.app` → `veaf_tools.commands` → `veaf_mission_mcp.server` → `mcp` → `starlette`, `uvicorn`; `commands.build` → `weather_injector` → `avwx`, `geopy` | `VERSION` moved to `veaf_libs/tool_version.py`; `veaf_tools.app` re-exports it |
| `diagnostics._collect_veaf` | → `lua_module_scanner.generate_modules_config_lua` → `lua_config_generator` → `checklists` → `pydantic` → `pydantic.mypy` → `mypy`; also `mission_tools`, and `veaf_libs.logger` → `rich` → `pygments.formatters.img` → `PIL` (7.3 MB, the largest single item) | the wrapper had no caller since `f959bd34` (2026-05-19): removed |

An intermediate build (edge 1 cut, wrapper still there) had dropped `mcp` and the CLI but kept
`mypy` and `PIL` (63.2 MB). A spec exclusion for `PIL` was tried, then measured useless once the
wrapper was gone (48 024 354 B without it, 48 024 729 B with it) and dropped: the spec is unchanged.

A new CI step in `veaf-logs-exe-smoke` fails if `mypy`, `mcp`, `uvicorn`, `starlette`,
`veaf_mission_mcp`, `PIL`, `pydantic` or `veaf_tools.app` / `veaf_tools.commands` appear in the archive, or if `paramiko` is missing
(checked against both archives: the old one is caught, the new one passes).

### Measured (PyInstaller 6.22.3, Windows 11, same machine, back to back)

| | before (`develop` b825b654) | after |
|---|---|---|
| `dist/veaf-logs.exe` | 68 659 055 B | **48 024 354 B** (−30 %) |
| Archive entries `mypy` / `mcp` / `uvicorn` / `starlette` | 77 / 107 / 41 / 22 | 0 / 0 / 0 / 0 |
| `PIL` / `pydantic` / `typer` / `pygments` / `tzdata` | 88 / 105 / 29 / 336 / 627 | 0 / 0 / 0 / 0 / 0 |
| `paramiko` / `requests` / `PySide6` | 40 / 18 / 133 | 40 / 18 / 133 |
| Cold start, launch → window, median | 14.78 s (3 runs; 15.37 s over 5 earlier) | **14.23 s** (5 runs) |

The single `__mypyc` entry left belongs to `charset_normalizer` (mypyc runtime, a real dependency
of `requests`), not to `mypy`.

**Cold start barely moves** (−0.5 s): the 14 s are not the archive size. Not investigated here. Filed as
[FIX-LOGS-EXE-STARTUP-AND-VERSION](../FIX-LOGS-EXE-STARTUP-AND-VERSION/PRD.md) ticket 01.

### Checked in the built executable

- Local `dcs.log` opened, lines displayed.
- Remote: the restored session reopened three `dcs.veaf.org` tabs; the exe wrote their SFTP
  mirrors (0.8 MB, 5.2 MB, 1.9 MB, each starting with a genuine DCS log line) within 30 s of launch.
- `poetry run pytest` green (coverage 87.99 %, gate 87.0 %); ruff, ruff format, mypy clean.

### Noticed, not fixed

- `tool.version` is most likely `unknown` in the `veaf-logs` report, before and after this lot:
  the recipe bundles no `veaf-tools` metadata, and `veaf-build` restores the `_version.py` stub
  before the release workflow runs `pyinstaller veaf-logs.spec`. Read from the code, not measured in
  a running exe. Filed as
  [FIX-LOGS-EXE-STARTUP-AND-VERSION](../FIX-LOGS-EXE-STARTUP-AND-VERSION/PRD.md) ticket 02.

## Tickets, in full

## 01 — cut the import chain, or exclude the packages

Status: ✅ done
Type: chore
Files: possibly `veaf-logs.spec`, `src/python/veaf-tools/veaf_libs/diagnostics.py`,
`src/python/veaf-tools/veaf_logs/report.py`

### What

1. Confirm the chain with `build/veaf-logs/xref-veaf-logs.html` (who imports `mcp`, `mypy`,
   `uvicorn`) or `python -X importtime -c "import veaf_logs.ui.main_window"` for the runtime side.
2. Prefer cutting the edge if it is a delayed or optional import in `veaf_libs.diagnostics`
   (the viewer only needs `BLOCK_START`, `BLOCK_END` and `DiagnosticReport`); otherwise add the
   top-level packages to the `excludes` list of `veaf-logs.spec`, next to the unused Qt modules,
   each with the one-line reason the recipe already gives for the others.
3. Rebuild, measure size and cold start, run `pyi-archive_viewer -l` to prove the packages are gone,
   and open a local and a remote log with the built exe.

### Done when

The PRD's definition of done holds and the numbers are written in the PRD.
