# 02 — set_unit_properties: callsign word plus digits, one pylon shape, a non-string CLSID refused

Status: ⬜ ready

Files: `veaf_mission_mcp/set_unit_properties.py`, `veaf_mission_mcp/actions.py` (schema text), tests.

## What happened

- `callsign={family: 1, name: "Texaco", flight: 2, number: 1}` wrote `name = "Texaco"` verbatim
  (`table["name"] = str(callsign["name"])`); the editor writes `Texaco21`. Passing `Texaco21` works, but the
  schema calls `name` the spoken name, which reads as the word alone.
- `_apply_pylons` does `str(clsid)`. Given `{station: {"CLSID": "…"}}` — the shape `add_air_group`,
  `create_qra` and `create_cap_mission` take, and the one the mission file stores — it wrote
  `"{'CLSID': '{6CEB…}'}"` as the CLSID of 16 aircraft, with no error.

## Done when

- A `name` without trailing digits is completed with the flight and number (`Texaco` → `Texaco21`); a name
  that already ends with them is kept.
- `pylons` accepts both shapes, `{station: "CLSID"}` and `{station: {"CLSID": "…"}}`, and refuses anything
  else (a dict without `CLSID`, a list, a number), naming the station.
- Tests for both shapes, the refusal and the completed name.
