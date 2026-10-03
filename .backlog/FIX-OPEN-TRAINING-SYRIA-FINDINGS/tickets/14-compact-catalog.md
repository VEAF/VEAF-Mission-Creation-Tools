# 14 — list_catalog fits in an agent's tool result

Status: ✅ done

Files: `veaf_mission_mcp/server.py`, `veaf_mission_mcp/catalog.py`, tests.

## What happened

`list_catalog` returned 67 388 characters, every action's full schema: the client saved it to a file instead
of showing it, and the agent had to read it back in pieces. `describe_action` already gives one schema.

## Done when

- `list_catalog` returns the name and the first line of the description of each action (a few kB);
  `describe_action` unchanged; `full: true` keeps today's output.
