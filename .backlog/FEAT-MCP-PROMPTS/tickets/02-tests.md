# 02 — Tests through the SDK client

Status: ✅ done
Files: `test/python/veaf_mission_mcp/test_prompts.py`

Through `mcp.Client(server.mcp)`: `prompts/list` (names, titles, French argument descriptions, required flags), `prompts/get` with optional arguments absent then present, blank, a missing required argument, a language other than `fr`/`en`, special characters. Coherence: each message points at the right `kind`, stays short and does not copy the mission prompt, each kind loads in both languages, each cited action exists in the catalogue and the guide names it, the compact profile serves the same prompts.
