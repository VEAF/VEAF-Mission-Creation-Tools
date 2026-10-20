# 04 — The MCP server updates itself

Status: ✅ done

At server start, in the background, at most once every 4 hours and only when update checks are enabled: if the latest release is newer than the running version, start `veaf-tools-updater.exe` detached and hidden, in the server's folder, with `VEAF_UPDATER_NO_PAUSE=1`. Never writes to stdout (the MCP channel); every failure is silent. The new version is used from the next client start.

Done: tests for the throttle, the version comparison and the launch command.
