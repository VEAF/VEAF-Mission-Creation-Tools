# FIX-LOGS-EXE-STARTUP-AND-VERSION — `veaf-logs.exe` takes 14 s to open and reports no version

Status: 🔄 in-progress — every ticket done and measured in the built exe 2026-10-03; closes with the merge

## Origin

Found while closing [CHORE-LOGS-EXE-TRIM](../archive/CHORE-LOGS-EXE-TRIM.md) on 2026-09-30. Paused until
the 6.26.0 release, picked up 2026-10-03.

## Measured / read (filing)

| | |
|---|---|
| Cold start, launch → window visible, median (Windows 11, DAVID-BUREAU) | 14.78 s at 68.7 MB, **14.23 s at 48.0 MB** |
| `tool.version` in the report built by `veaf-logs` | most likely `unknown` — read from the code, **not measured in a running exe** |

Removing 20 MB saved 0.5 s: the 14 s are not the archive size.

## Where the seconds went (2026-10-03)

Method: `dist/veaf-logs.exe` built from `develop` (PyInstaller 6.22.3), launched from a script that
times process start → the first top-level window handle, then kills the process (so no session is
saved). `APPDATA` pointed at a copy of the user's data or at an empty folder to change one thing at a
time.

| Run (median) | Window after |
|---|---|
| David's real `%APPDATA%` | **9.2 – 10.5 s** |
| empty `%APPDATA%` (no session) | 1.8 s |
| from source (`python -m veaf_logs`), same session | 1.4 s |

Bisecting `%APPDATA%` with junctions (224 folders) isolated `%APPDATA%\veaf_logs`, i.e. the session
itself: it held three remote tabs (`veaf/bot`, `veaf/private1`, `veaf/private2`). A self-profiling
build of the same spec (cProfile from process start to `MainWindow.show`) put **7.9 s of 10.0 s in
`_reopen_remote`**: `MainWindow.__init__` → `_restore` connected over SSH (0.85 s each) and mirrored
each log over SFTP before `run()` reached `window.show()`. The onefile extraction costs ~0.4 s
(1.8 s exe vs 1.4 s source), so `--onedir` would not buy anything worth shipping a folder for. The
14 s of the filing were the same cause on a slower network day.

| After the fix (median of 5) | Window after |
|---|---|
| David's real `%APPDATA%` (three remote tabs) | **2.27 s** (10.45 s before, same run) |
| empty `%APPDATA%` | 2.22 s |

The three remote tabs still reopen: their three SFTP mirrors were written within 25 s of launch.

## The version (2026-10-03)

Read in the exe built from `develop`, through `PyInstaller.archive.readers`: the PYZ carries
`veaf_tools._version` with `('unknown', '')`, and the archive no `veaf-tools` distribution metadata,
so `importlib.metadata` cannot answer first. Confirmed: every shipped report said
`tool.version: unknown`. Built with the new `veaf-build build-logs --version 6.26.0-check`, the same
module carries `('6.26.0-check', '37c2eb43')`.

**Left as is, on purpose.** The SSH connection and the first copy still run on the GUI thread: the
window is up, but it does not answer for the second or two each remote tab takes, one tab at a time.
Moving them to a worker thread means taking the host-key prompt (a dialog, GUI thread only) out of
`_connect`; not worth it while nobody has complained of a freeze, as opposed to a window that did not
appear.

## Found on the way

`MainWindow.closeEvent` saves the session to `%APPDATA%\veaf_logs\session.json`, and nothing in the
`veaf_logs` tests redirected it: every local `pytest` replaced the developer's session with a test
journal under `pytest-of-<user>`. Seen in a sandboxed copy of `%APPDATA%` holding exactly that. Ticket
03. Also, `default_session_path`'s docstring still named the pre-rename `dcslog` folder, which sent
this investigation to a stale file first; corrected.

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| [01](tickets/01-cold-start.md) | Find where the 14 s go, then cut them | ✅ |
| [02](tickets/02-report-version.md) | Make the `veaf-logs` report carry the real version | ✅ |
| [03](tickets/03-tests-keep-off-the-user-session.md) | The tests stop overwriting the user's `veaf-logs` session | ✅ |

## Definition of done

- [x] The cold start is measured with the method of CHORE-LOGS-EXE-TRIM, before and after, and the
  numbers are written here; the cause is named by a measurement, not assumed.
- [x] A release-built `veaf-logs.exe` puts the shipped version in `tool.version`, checked in the exe
  (and now in CI: `veaf-logs-exe-smoke` reads the module out of the built archive).
