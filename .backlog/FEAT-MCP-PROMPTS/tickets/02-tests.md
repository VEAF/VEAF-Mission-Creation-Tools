# 02 — Tests through the SDK client

Status: ✅ done
Files: `test/python/veaf_mission_mcp/test_prompts.py`

Written first (TDD). Through `mcp.Client(server.mcp)`: `prompts/list` (names, argument descriptions in French, required flags), `prompts/get` with optional arguments absent then present, a missing required argument, a wrong type, special characters (quotes, accents, newline, backtick). A coherence test: every action a prompt cites exists in the catalogue and is named in the authoring guide; the standard and compact profiles serve the same prompts.
