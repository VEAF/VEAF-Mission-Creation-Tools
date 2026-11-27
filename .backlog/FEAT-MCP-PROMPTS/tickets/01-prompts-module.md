# 01 — Prompt texts and registration

Status: 🔄 in progress
Files: `src/python/veaf-tools/veaf_mission_mcp/prompts.py`, `server.py`

Write the four prompts (`nouvelle_mission`, `ajouter_qra`, `ajouter_zone_de_combat`, `ajouter_jtac`) as pure functions returning the French text, typed arguments with French descriptions, and register them on `mcp` in `server.py`. The mission-table convention (`x` north, `y` east) is the one of `docs/agents/dcs-coordinates.md`. Done when ticket 02 passes.
