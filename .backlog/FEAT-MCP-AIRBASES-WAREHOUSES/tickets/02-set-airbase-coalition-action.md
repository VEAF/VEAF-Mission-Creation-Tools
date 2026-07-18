# 02 — `set_airbase_coalition` MCP action

Status: ⬜ ready

## Goal

Expose an MCP action that assigns a DCS airfield to a coalition, durably, in the mission folder.

## Details

- `set_airbase_coalition(target, *, name, coalition)` where `coalition ∈ {blue, red, neutral}`.
- Loads the folder mission, uses the ticket-01 helper to get/create the airfield entry, sets
  `entry["coalition"] = coalition.upper()`, saves the folder (backup first, reusing
  `save_folder_mission`).
- Register in `actions.py` + `catalog.py` with a `coalition` enum, mirroring the existing action
  registration pattern (e.g. `add_trigger_zone`).
- Returns `{airbase, airdrome_id, coalition, durable: true}`.

## Tests

- Assigning blue writes `warehouses.airports[<id>].coalition == "BLUE"` and persists after reload.
- Neutral / red likewise.
- Catalog/describe exposes the action with the coalition enum.
