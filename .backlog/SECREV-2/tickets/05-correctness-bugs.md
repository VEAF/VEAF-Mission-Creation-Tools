# 05 — The two high-severity correctness bugs

Status: ✅ done — both confirmed by a failing test first, then fixed
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

- [x] **Reused the index-rewrite** rather than routing through `VeafTriggerSpec`. Both were
      allowed; the rewrite is the smaller change and keeps the bridge's "always index 1" contract
      explicit, where routing would have had to express that ordering through a spec. The
      substitution is applied **per entry, with that entry's own key**, so neighbours cannot
      cross-talk — a blanket `[1]`→`[2]` pass over the whole category would corrupt trigger 2.
- [x] Test written **first** and confirmed failing on the real defect: the shifted trigger came
      back as `conditions[1]`, the bridge's own pair. 8 tests, including a three-trigger case
      that is where a colliding rewrite would show, and a no-op case for `bridge_file=None`.
- [x] Impact: builds with `dcs_bridge.enabled` **and** at least one pre-existing trigger were
      load-broken. Missions with no prior trigger were unaffected, which is why this survived —
      the default mission has none, so the common path never showed it.

## VMR-006 — the live METAR fetch never fetches

`dcs_weather_converter.py` does `metar = Metar(airport_icao)` and then reads `metar.temperature`,
`metar.wind_speed`, and so on. In avwx, **the constructor does not fetch** — `.update()` does. So the
attributes are empty and the function silently returns its defaults. A mission asking for live weather
gets canned weather, with no error.

Verified 2026-08-05: there is exactly one `Metar(` in the file and no `.update()` anywhere.

- [x] `.update()` is called and **its return value checked**. That second half matters as much as
      the first: avwx signals a failed fetch by returning `False` rather than raising, so calling
      `update()` and ignoring the result would have reinstated exactly the same silence.
- [x] Failure paths are explicit and announced at warning level, each naming the ICAO: fetch
      returned nothing, and avwx absent. New i18n key in both locales.
- [x] 7 tests against a faked avwx — no package, no network needed. The fake only populates its
      attributes inside `update()`, exactly like the real one, so the tests fail structurally
      without the fix rather than by accident.
