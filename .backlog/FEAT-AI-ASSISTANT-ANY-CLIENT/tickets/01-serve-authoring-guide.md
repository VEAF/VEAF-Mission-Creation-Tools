# 01 — Serve the authoring guide over MCP

Status: ✅ done

Type: feature

`describe_authoring_guide` returns the plugin's `SKILL.md` verbatim; `_veaf_tools_extra_data` bundles it under `veaf_mission_mcp/data`; the server's `instructions` ask the client to read it first unless the skill is loaded.
