# CHORE-LOGS-EXE-TRIM — `veaf-logs.exe` carries the MCP server and mypy it never runs

Status: ⬜ ready — filed 2026-09-25

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

## Cause (hypothesis, to confirm on the xref)

PyInstaller follows imports statically, delayed and conditional ones included. `veaf_logs/report.py`
imports `veaf_libs.diagnostics`; from there the graph reaches `veaf_libs.i18n`, `veaf_libs.logger`,
`veaf_libs.lua_config_generator`, `veaf_libs.checklists`, `veaf_libs.mission_validator`,
`veaf_mission_mcp.catalog`, the MCP stack, and pydantic's `pydantic.mypy` plugin, which drags `mypy`
(a dev dependency) into a shipped executable. None of it runs in the log viewer.

## Ticket

| # | Ticket | Status |
|---|--------|--------|
| [01](tickets/01-cut-the-import-chain.md) | Cut the chain or exclude the packages, measure before/after | ⬜ |

## Definition of done

- `pyi-archive_viewer -l dist/veaf-logs.exe` finds no `mypy`, `mcp`, `uvicorn`, `starlette` entry.
- `paramiko` is still bundled (lazily imported by `veaf_logs/remote.py`; listed in `hiddenimports`).
- Size and cold-start time of the exe measured before and after and written here.
- `poetry run pytest test/python/veaf_logs` green; the exe opens a local `dcs.log` and a remote one.
