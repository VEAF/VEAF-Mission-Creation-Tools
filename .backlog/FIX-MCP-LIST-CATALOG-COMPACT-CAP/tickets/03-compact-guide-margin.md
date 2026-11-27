# 03 — The compact guide keeps a margin under its cap

Status: ⬜ ready
Type: fix (budget)
Files: `src/python/veaf-tools/veaf_mission_mcp/data/authoring-guide.md`, `src/python/veaf-tools/veaf_mission_mcp/` (the compact cap), `test/python/veaf_mission_mcp/test_context_budget.py`

The compact default guide is 7 848 characters for a cap of 8 000, after FIX-MCP-REPLAY-FINDINGS raised the test margin from 7 600 to 7 900. One more sentence breaks the cap, and a response over the cap is cut.
Measure the sections of the compact default guide (characters each) and what the cap cuts when exceeded. Then either make room (shorten wording that repeats between sections, with no information lost) or move a section out of the default answer into one the model reads on demand. Do this together with ticket 01 of this lot, since both change the compact answers' size.
Test: a margin of at least 300 characters under the cap, so the test fails before the cap is hit; the chain budget (reference chain under 50 000) still holds. The standard profile keeps the full guide.
