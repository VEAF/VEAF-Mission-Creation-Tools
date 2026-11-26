# 01 — Study where Cherry Studio 2.2.x keeps its MCP servers

Status: ⬜ ready
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
