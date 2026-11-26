# 01 — Study where Cherry Studio 2.2.x keeps its MCP servers

Status: ✅ done
Type: study
Files: none (a report; nothing is coded)

Find out, without assuming, how `ai-setup` could declare the VEAF MCP server in Cherry Studio 2.2.x and link it to an assistant.
Leads to check, each proved or marked unproved:
- The `%APPDATA%\CherryStudio\Data\cherrystudio.sqlite` database: the table that holds the MCP servers, the row format, whether it can be read or written with Cherry closed, with Cherry open, and with its WAL file.
- What changes between Cherry versions (the risk of a silent break) and how a version check could refuse instead of corrupting.
- The JSON import of the interface, and whether a file can be dropped where Cherry reads it.
- An install link of the form `cherrystudio://mcp/install?...` (believed to exist, not verified).
- The link between an assistant and an MCP server (made inside the assistant, by identifier): is it reachable from outside?

Deliverable: a verdict **feasible / risky / no**, with what is proved (cite the source file and line in `CherryHQ/cherry-studio`) and what is not.
If "no" or "risky", say what is left to the user and how the tutorial documents it; ticket 02 is then dropped or reduced.

**Verdict (2026-11-26): feasible, with Cherry closed.** Proved in the code of tag `v2.2.3`: the `mcp_server` and `assistant_mcp_server` tables, Cherry rereading the server list on each chat request, and its UI replacing an assistant's links on save. The `cherrystudio://mcp/install` link exists but opens a dialog, installs the server inactive and untrusted, cannot link an assistant and refuses an existing name, so it does not remove the manual step. Cherry reads no JSON file for MCP servers. The mechanism and its guards are in ticket 02.
