# 01 — The self-update never replaces a running exe

Status: ⬜ ready

Today `start_update_if_due` (in `veaf_mission_mcp/self_update.py`) launches the updater, whose `_install_beside_running_exe` renames the running exe aside and moves the new one in — under the server that launched it and every other server running.

Instead:
- the server downloads the new exe beside the installed one (staged, not installed);
- the swap happens at a server start, before anything else is imported, and only when no other `veaf-tools.exe` process runs: the starting server renames itself aside, moves the staged exe in, and runs the new exe `mcp` as its child on the same standard input and output, exiting with its code;
- otherwise the staged exe waits for a later start; the running servers keep working.

The updater run by a user (`veaf-tools-updater.exe`) keeps its current behaviour, but warns when a `veaf-tools.exe` is running.

Done when:
- a test swaps the exe under a running server in the CI-built executable, or the swap logic is tested with the process list and the file moves injected;
- the scenario of the measurement (four servers, an update published mid-session) leaves every running server answering;
- `known-limitations.yaml` records the PyInstaller behaviour (`kind: tool`, fixed in 6.31.2), the CHANGELOG and the install page say an update lands at the next start of the AI.

Note: 6.31.2 itself reaches running 6.31.0/6.31.1 servers through the old mechanism, once.
