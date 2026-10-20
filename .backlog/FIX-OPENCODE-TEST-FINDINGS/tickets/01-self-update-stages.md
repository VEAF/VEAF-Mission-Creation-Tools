# 01 — The self-update never replaces a running exe

Status: ✅ done

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

## Done (2026-10-20)

- `veaf_libs/staged_update.py`: `take_staged_update` puts `veaf-tools.exe.staged` in place and runs it as a child on the same standard streams, only when `running_copies` finds no other process running from the file or from a copy set aside (Windows through `EnumProcesses` / `QueryFullProcessImageNameW`, Linux through `/proc`; any other platform waits).
  The child gets `PYINSTALLER_RESET_ENVIRONMENT=1`: same path as its parent, it would otherwise take the parent's unpacked folder for its own.
  Called from `veaf-tools.py` for `mcp` only, before `main()`; once swapped the process imports nothing more and exits with the child's code (`os._exit`).
- The server's self-update runs the updater with `--stage` (hidden option): the new `veaf-tools.exe` goes to `veaf-tools.exe.staged`; the updater replaces itself as before.
- A run by hand warns when a `veaf-tools.exe` is running, and puts a staged version in place (`published/` already carries its version, so the version check alone would never install it).
- Tests: the swap logic with the process list and the launch injected (`test_staged_update.py`), the real process table on a copied system program, the updater's stage mode (Windows and Unix) and the run by hand.
- Verified on a locally built 6.31.2 (`stage_test.py`, derived from `swap_test.py`): four servers running, the built updater run with `--stage` → exe unchanged, `veaf-tools.exe.staged` written, and all four answered `set_airbase_coalition`, `validate_mission` and `describe_known_limitations` (first-time imports); a fifth server started among them did not swap; the four stopped, a lone start swapped and answered as 6.31.1, the staged file gone, the old exe set aside.
- `known-limitations.yaml`: `self-update-broke-running-servers` (`kind: tool`, `fixed_in: 6.31.2`); install page (both languages) and `TOOLS_REFERENCE` say an update lands at the next start of an assistant.
