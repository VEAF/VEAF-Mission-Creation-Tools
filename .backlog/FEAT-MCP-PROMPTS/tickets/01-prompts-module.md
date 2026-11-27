# 01 — Prompts module and registration

Status: ✅ done
Files: `src/python/veaf-tools/veaf_mission_mcp/prompts.py`, `server.py`

Three prompts (`mission_one_shot`, `open_training`, `campagne_persistante`) as pure functions returning a short French message, typed arguments with French descriptions, registered on `mcp` in `server.py` with a title and a description. Each message tells the model to load the mission prompt of its kind with `describe_mission_prompt` and follow it; none copies it.
