# 01 — `list_catalog` fits the compact cap

Status: ⬜ ready
Type: fix
Files: `src/python/veaf-tools/veaf_mission_mcp/` (`list_catalog` and the compact cap in `run_action`), `test/python/veaf_mission_mcp/test_context_budget.py` (or the file that holds the budget tests)

Measure first, in both profiles: the length of the `list_catalog` answer, whether `run_action` cuts it, and what the cut loses (which actions fall off the end).
Then make the compact answer fit under the cap without losing an action: shorter summaries in the compact profile (the catalogue summaries are already 60 characters in compact, check that rule still applies here), or a two-step answer (names first, a summary on demand), whichever the measure supports. The standard profile keeps its full answer.
Test: in compact, the `list_catalog` answer is under the cap and lists every action; a test fails when the action count grows past the cap, so the next added action cannot silently cut the list again.
