# 01 — The guide's examples must not tempt a model to run them as written

Status: ⬜ ready
Type: fix (guide text)
Files: `src/python/veaf-tools/veaf_mission_mcp/data/authoring-guide.md`, the mission prompts if they carry the same example, `test/python/veaf_mission_mcp/` (the guide and budget tests)

The model scaffolded `C:\VEAF-Missions\test` (Caucasus, Beslan, 2024-06-10), the example of `scaffold_mission` / `adapt_scaffold` in the guide.
Find every concrete path, name and date used as an example in the guide and the three mission prompts; write them as placeholders (`<folder>`, `<map>`) or say once, in the recipe, that the values are examples to replace by the user's answers. Keep both profiles' budget tests green (compact guide cap, chain budget).
Test: no example in the guide names a real-looking mission folder (a pattern check).
