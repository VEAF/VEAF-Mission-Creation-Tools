# 01 — Updater: replace a running veaf-tools.exe

Status: ✅ done

`_install_windows_binaries` moves the new `veaf-tools.exe` over the old one; when an MCP server runs it, the move fails and the install is reported failed in a window nobody sees. Rename the running file aside (`veaf-tools.exe.old`, allowed by Windows), put the new one in place, and delete leftover `.old` files on the next run.

Done: a test where the destination cannot be overwritten but can be renamed installs the new binary.
