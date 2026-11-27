# 02 — The guide's recipe keeps no real value a model could copy

Status: ⬜ ready
Type: fix (guide text and test)
Files: `src/python/veaf-tools/veaf_mission_mcp/data/authoring-guide.md`, `test/python/veaf_mission_mcp/` (the anti-replay test of the guide)

Ticket 01 of FIX-MCP-REPLAY-FINDINGS replaced the folder, map, place, name and date by placeholders. The recipe still carries `country_name: "Israel"`, a unit type `Merkava_Mk4`, a JTAC `1511` and frequency `35.55`, and `"language": "fr"`; a model can copy them into a mission that has nothing to do with Israel.
Measure first: list every concrete value in the recipe's calls (country, unit type, code, frequency, language, coordinates) and which are a real default and which are an example. Replace the examples by placeholders or by values that stay valid anywhere; keep a real default (for instance a language default) where the tool itself defaults to it, and say so.
Extend the anti-replay test beyond folder, map, place, name and date to these keys, so the next example cannot slip in. Keep the compact guide under its cap.
