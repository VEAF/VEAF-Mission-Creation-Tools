# 05 — The two high-severity correctness bugs

Status: ⬜ ready
Type: fix
Findings: VMR-005 🟠 CONFIRMED, VMR-006 🟠 CONFIRMED

## VMR-005 — the dcs-bridge trigger shift breaks every existing trigger

`inject_dcs_bridge_trigger()` makes room at index 1 by shifting every trig category up
(`{k + 1: v for k, v in category_data.items()}`) but does **not** rewrite the Lua text of the shifted
triggers. Those strings hardcode their own indices — `if mission.trig.conditions[1]() then
mission.trig.actions[1]() end` — so after the shift, the trigger now at key 2 still invokes
`conditions[1]`, which is the bridge's. Every previously inserted trigger runs the wrong pair.

`insert_veaf_triggers()` gets this right: it regex-rewrites `[old]`→`[new]` inside the string values.
So the fix is not new logic, it is **using the logic that exists** — or routing the bridge through the
same insertion path so the shift and the rewrite stay in one place.

Verified 2026-08-05: the shift is still there, with no rewrite.

- [ ] Reuse the index-rewrite, or route the bridge through `VeafTriggerSpec`.
- [ ] A test building a mission with an existing trigger **and** the bridge, asserting the existing
      trigger still references its own condition/action pair.
- [ ] Impact note: this makes `dcs_bridge.enabled` builds load-broken, so check whether any shipped
      mission has it on before deciding urgency.

## VMR-006 — the live METAR fetch never fetches

`dcs_weather_converter.py` does `metar = Metar(airport_icao)` and then reads `metar.temperature`,
`metar.wind_speed`, and so on. In avwx, **the constructor does not fetch** — `.update()` does. So the
attributes are empty and the function silently returns its defaults. A mission asking for live weather
gets canned weather, with no error.

Verified 2026-08-05: there is exactly one `Metar(` in the file and no `.update()` anywhere.

- [ ] Call `.update()` (or the async equivalent) and check its return before reading attributes.
- [ ] Handle the failure path explicitly: no network, unknown ICAO, avwx absent. Silently falling back
      to defaults is what hid this for a month — say so in the log at warning level.
- [ ] A test with a faked avwx asserting that values reach the result, and a second asserting the
      fallback announces itself.
