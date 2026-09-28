# 01 — Aircraft built with no chaff, no flare, no callsign, and repeating tail numbers

Status: ⬜ ready
Type: fix
Files: `src/python/veaf-tools/veaf_mission_mcp/aircraft_payload.py`, `add_air_group.py`,
`player_slot.py`, `set_unit_properties.py`, the unit data, tests

## Origin

GermanyCW-v6, 2026-09-28: the player-versus-player arena, 23 flights of four client slots in air
start, built with `add_air_group` (`skill: "Client"`, `start: "air"`, a loadout).

## Measured

1. **No countermeasures.** `build_aircraft_payload` starts every payload from
   `{"flare": 0, "chaff": 0, "gun": 100, "pylons": {}}` (`aircraft_payload.py:48`). An air-start
   client cannot rearm: every arena pilot went into a missile fight with an empty dispenser. The
   figures the Caucasus v5 arena carried, and the ones the dynamic-slot templates carry: F-14B
   140 / 60, F-16C 60 / 60, F/A-18C 60 / 30, M-2000C 112 / 16, Su-27 and J-11A 96 / 96, Su-33
   48 / 48, MiG-29 30 / 30, JF-17 36 / 32, MiG-21bis 32 / 32, Mirage F1EE 30 / 15.
2. **No action sets them afterwards.** `set_unit_properties` takes skill, livery, heading, callsign,
   onboard number, pylons, name and position — not chaff, flare or gun.
3. **No callsign.** Neither `add_air_group` nor `player_slot` writes `callsign`: the 56 western
   arena aircraft came out with none (`describe_units` → `"callsign": null`), where the editor
   gives every western aircraft a family / flight / number.
4. **Tail numbers repeat.** `add_air_group.py:483` numbers a flight `10 + i`, restarting at 10 in
   every group: the E-3A Overlord 1, the KC-135 Arco 1 and the first arena F-14B all carried `10`.

Worked around by one script on the table (the 92 arena units): chaff and flare per type, a callsign
per type and fox level, tail numbers 701 onwards.

## Done when

- A new aircraft carries its type's default chaff and flare. The source is a choice to make and to
  write down: the DCS unit database (`passivCounterm` defaults, captured by `update-dcs-data`) or
  the mission's own dynamic-slot template of that type. No hard-coded table.
- `add_air_group` and `add_player_slot` take `chaff` / `flare` to override, and so does
  `set_unit_properties`.
- A western aircraft gets a callsign (family, flight, number, spoken name); an eastern one its
  numeric callsign.
- Tail numbers are unique across the mission's aircraft.
- Tests on each point, and the AI catalogue doc says it.
